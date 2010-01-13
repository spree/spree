require 'ostruct'
class Shipment < ActiveRecord::Base
  belongs_to :order
  belongs_to :shipping_method
  belongs_to :address
  has_one    :shipping_charge,   :as => :adjustment_source
  alias charge shipping_charge
  has_many :state_events, :as => :stateful
  has_many :inventory_units
  before_create :generate_shipment_number
  after_save :create_shipping_charge

  attr_accessor :special_instructions
  accepts_nested_attributes_for :address
  accepts_nested_attributes_for :inventory_units

  def shipped=(value)
    return unless value == "1" && shipped_at.nil?
    self.shipped_at = Time.now
  end

  def create_shipping_charge
    if shipping_method
      self.shipping_charge ||= ShippingCharge.create({
          :order => order,
          :description => description_for_shipping_charge,
          :adjustment_source => self,
        })
    end
  end

  def cost
    shipping_charge.amount if shipping_charge
  end

  # shipment state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'pending' do
    event :ready do
      transition :from => 'pending', :to => 'ready_to_ship'
    end
    event :pend do
      transition :from => 'ready_to_ship', :to => 'pending'
    end
    event :ship do
      transition :from => 'ready_to_ship', :to => 'shipped'
    end

    after_transition :to => 'shipped', :do => :transition_order
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
    if order.checkout_complete
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
    order.update_adjustments
    order.save
  end

  private

  def generate_shipment_number
    return self.number unless self.number.blank?
    record = true
    while record
      random = Array.new(11){rand(9)}.join
      record = Shipment.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end

  def description_for_shipping_charge
    "#{I18n.t(:shipping)} (#{shipping_method.name})"
  end

  def transition_order
    update_attribute(:shipped_at, Time.now)
    # transition order to shipped if all shipments have been shipped
    order.ship! if order.shipments.all?(&:shipped?)
  end

end