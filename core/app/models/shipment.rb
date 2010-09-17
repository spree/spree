require 'ostruct'
class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
  belongs_to :address
  has_many :state_events, :as => :stateful
  has_many :inventory_units
  before_create :generate_shipment_number
  after_destroy :release_inventory_units

  attr_accessor :special_instructions
  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :inventory_units

  validates :inventory_units, :presence => true, :if => Proc.new { |shipment| shipment.order.completed? && !shipment.order.canceled? }
  make_permalink :field => :number
  validate :shipping_method

  scope :shipped, where(:state => 'shipped')
  scope :ready, where(:state => 'ready')
  scope :pending, where(:state => 'pending')

  def to_param
    self.number if self.number
    generate_shipment_number unless self.number
    self.number.parameterize.to_s.upcase
  end

  def shipped=(value)
    return unless value == "1" && shipped_at.nil?
    self.shipped_at = Time.now
  end

  # The adjustment amount associated with this shipment (if any.)  Returns only the first adjustment to match
  # the shipment but there should never really be more than one.
  def cost
    adjustment = order.adjustments.shipping.detect { |adjustment| adjustment.source == self }
    adjustment ? adjustment.amount : 0
  end

  # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'pending', :use_transactions => false do
    event :ready do
      transition :from => 'pending', :to => 'ready'
    end
    event :pend do
      transition :from => 'ready', :to => 'pending'
    end
    event :ship do
      transition :from => 'ready', :to => 'shipped'
    end

    #after_transition :to => 'shipped', :do => :transition_order
  end

  def editable_by?(user)
    !shipped?
  end

  def manifest
    inventory_units.group_by(&:variant).map do |i|
      OpenStruct.new(:variant => i.first, :quantity => i.last.length)
    end
  end

  def line_items
    if order.complete?
      order.line_items.select {|li| inventory_units.map(&:variant_id).include?(li.variant_id)}
    else
      order.line_items
    end
  end

  def recalculate_needed?
    changed? or !address.same_as?(Address.find(address.id))
  end

  def recalculate_order
    shipping_charge.update_attribute(:description, description_for_shipping_charge)
    order.update_totals!
  end

  def update!
    update_attribute_without_callbacks "state", determine_state
  end

  private

  def generate_shipment_number
    return self.number unless self.number.blank?
    record = true
    while record
      random = "H" + Array.new(11){rand(9)}.join
      record = Shipment.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end

  def description_for_shipping_charge
    "#{I18n.t(:shipping)} (#{shipping_method.name})"
  end

  # def transition_order
  #   update_attribute(:shipped_at, Time.now)
  #   # transition order to shipped if all shipments have been shipped
  #   order.ship! if order.shipments.all?(&:shipped?)
  # end

  def validate_shipping_method
    unless shipping_method.nil?
      errors.add :shipping_method, I18n.t("is_not_available_to_shipment_address") unless shipping_method.zone.include?(address)
    end
  end

  def release_inventory_units
    inventory_units.each {|unit| unit.update_attribute(:shipment_id, nil)}
  end

  # Determines the appropriate +state+ according to the following logic:
  #
  # pending    unless +order.payment_state+ is +paid+
  # shipped    if already shipped (ie. does not change the state)
  # ready      all other cases
  def determine_state
    return "pending" if order.backordered?
    return "shipped" if state == "shipped"
    order.payment_state == "balance_due" ? "pending" : "ready"
  end
end
