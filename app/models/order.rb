class Order < ActiveRecord::Base
  module Totaling
    def total
      map(&:amount).sum
    end
  end

  before_create :generate_token
  before_save :update_line_items, :update_totals
  after_create :create_checkout, :create_shipment, :create_tax_charge

  belongs_to :user
  has_many :state_events, :as => :stateful

  has_many :line_items, :extend => Totaling, :dependent => :destroy
  has_many :inventory_units

  has_many :payments, :as => :payable, :extend => Totaling

  has_one :checkout
  has_one :bill_address, :through => :checkout
  has_one :ship_address, :through => :checkout
  has_many :shipments, :dependent => :destroy
  has_many :return_authorizations, :dependent => :destroy

  has_many :adjustments,      :extend => Totaling, :order => :position
  has_many :charges,          :extend => Totaling, :order => :position
  has_many :credits,          :extend => Totaling, :order => :position
  has_many :shipping_charges, :extend => Totaling, :order => :position
  has_many :tax_charges,      :extend => Totaling, :order => :position
  has_many :coupon_credits,   :extend => Totaling, :order => :position
  has_many :non_zero_charges, :extend => Totaling, :order => :position,
           :class_name => "Charge", :conditions => ["amount != 0"]

  accepts_nested_attributes_for :checkout
  accepts_nested_attributes_for :line_items
  accepts_nested_attributes_for :shipments

  delegate :shipping_method, :to => :checkout
  delegate :email, :to => :checkout
  delegate :ip_address, :to => :checkout
  delegate :special_instructions, :to => :checkout

  validates_numericality_of :item_total
  validates_numericality_of :total

  named_scope :by_number, lambda {|number| {:conditions => ["orders.number = ?", number]}}
  named_scope :between, lambda {|*dates| {:conditions => ["orders.created_at between :start and :stop", {:start => dates.first.to_date, :stop => dates.last.to_date}]}}
  named_scope :by_customer, lambda {|customer| {:include => :user, :conditions => ["users.email = ?", customer]}}
  named_scope :by_state, lambda {|state| {:conditions => ["state = ?", state]}}
  named_scope :checkout_complete, {:include => :checkout, :conditions => ["orders.completed_at IS NOT NULL"]}
  make_permalink :field => :number

  # attr_accessible is a nightmare with attachment_fu, so use attr_protected instead.
  attr_protected :charge_total, :item_total, :total, :user, :number, :state, :token

  def checkout_complete; !!completed_at; end

  def to_param
    self.number if self.number
    generate_order_number unless self.number
    self.number.parameterize.to_s.upcase
  end

  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'in_progress' do
    after_transition :to => 'in_progress', :do => lambda {|order| order.update_attribute(:checkout_complete, false)}
    after_transition :to => 'new', :do => :complete_order
    after_transition :to => 'canceled', :do => :cancel_order
    after_transition :to => 'returned', :do => :restock_inventory
    after_transition :to => 'resumed', :do => :restore_state
    after_transition :to => 'paid', :do => :make_shipments_ready
    after_transition :to => 'shipped', :do => :make_shipments_shipped
    after_transition :to => 'balance_due', :do => :make_shipments_pending

    event :complete do
      transition :to => 'new', :from => 'in_progress'
    end
    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end
    event :return do
      transition :to => 'returned', :from => 'credit_owed'
    end
    event :resume do
      transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
    end
    event :pay do
      transition :to => 'paid', :if => :allow_pay?
    end
    event :under_paid do
      transition :to => 'balance_due', :from => ['paid', 'new', 'credit_owed', 'shipped', 'awaiting_return']
    end
    event :over_paid do
      transition :to => 'credit_owed', :from => ['paid', 'new', 'balance_due', 'shipped', 'awaiting_return']
    end
    event :ship do
      transition :to => 'shipped', :from  => 'paid'
    end
    event :return_authorized do
      transition :to => 'awaiting_return', :from => 'shipped'
    end
  end

  def restore_state
    # pop the resume event so we can see what the event before that was
    state_events.pop if state_events.last.name == "resume"
    update_attribute("state", state_events.last.previous_state)
  end

  def make_shipments_shipped
    shipments.reject(&:shipped?).each do |shipment|
      shipment.update_attributes(:state => 'shipped', :shipped_at => Time.now)
    end
  end

  def make_shipments_ready
    shipments.each(&:ready)
  end

  def make_shipments_pending
    shipments.each(&:pend)
  end

  def shipped_units
    shipped_units = shipments.inject([]) { |units, shipment| units << shipment.inventory_units if shipment.shipped? }

    if shipped_units.nil?
      return nil
    else
      shipped_units.flatten!
    end

    shipped = {}
    shipped_units.group_by(&:variant_id).each do |variant_id, ship_units|
      shipped[Variant.find(variant_id)] = ship_units.size
    end
    shipped
  end

  def returnable_units
    returned_units = return_authorizations.inject([]) { |units, return_auth| units << return_auth.inventory_units}
    returned_units.flatten! unless returned_units.nil?

    returnable = shipped_units
    return if returnable.nil?

    returned_units.group_by(&:variant_id).each do |variant_id, returned_units|
      variant = returnable.detect { |ru| ru.first.id == variant_id }[0]

      count = returnable[variant] - returned_units.size
      if count > 0
        returnable[variant] = returnable[variant] - returned_units.size
      else
        returnable.delete variant
      end
    end

    returnable.empty? ? nil : returnable
  end

  def allow_cancel?
    self.state != 'canceled'
  end

  def allow_resume?
    # we shouldn't allow resume for legacy orders b/c we lack the information necessary to restore to a previous state
    return false if state_events.empty? || state_events.last.previous_state.nil?
    true
  end

  def allow_pay?
    checkout_complete
  end

  def add_variant(variant, quantity=1)
    current_item = contains?(variant)
    if current_item
      current_item.increment_quantity unless quantity > 1
      current_item.quantity = (current_item.quantity + quantity) if quantity > 1
      current_item.save
    else
      current_item = LineItem.new(:quantity => quantity)
      current_item.variant = variant
      current_item.price   = variant.price
      self.line_items << current_item
    end

    # populate line_items attributes for additional_fields entries
    # that have populate => [:line_item]
    Variant.additional_fields.select{|f| !f[:populate].nil? && f[:populate].include?(:line_item) }.each do |field|
      value = ""

      if field[:only].nil? || field[:only].include?(:variant)
        value = variant.send(field[:name].gsub(" ", "_").downcase)
      elsif field[:only].include?(:product)
        value = variant.product.send(field[:name].gsub(" ", "_").downcase)
      end
      current_item.update_attribute(field[:name].gsub(" ", "_").downcase, value)
    end

    current_item
  end

  def generate_order_number
    record = true
    while record
      random = "R#{Array.new(9){rand(9)}.join}"
      record = Order.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end

  # convenience method since many stores will not allow user to create multiple shipments
  def shipment
    @shipment ||= shipments.last
  end

  def contains?(variant)
    line_items.select { |line_item| line_item.variant == variant }.first
  end

  def grant_access?(token=nil)
    return true if token && token == self.token
    return false unless current_user_session = UserSession.find
    return current_user_session.user == self.user
  end
  def mark_shipped
    inventory_units.each do |inventory_unit|
      inventory_unit.ship!
    end
  end

  # collection of available shipping countries
  def shipping_countries
    return [] unless ShippingMethod.count > 0
    ShippingMethod.all.collect { |method| method.zone.country_list }.flatten.uniq.sort_by {|item| item.send 'name'}
  end

  def shipping_methods
    return [] unless ship_address and ShippingMethod.count > 0
    ShippingMethod.all_available_to_address(ship_address)
  end

  def payment_total
    payments.reload.total
  end

  def ship_total
    shipping_charges.reload.total
  end

  def tax_total
    tax_charges.reload.total
  end

  def credit_total
    credits.reload.total.abs
  end

  def charge_total
    charges.reload.total
  end

  def create_tax_charge
    if tax_charges.empty?
      tax_charges.create({
          :order => self,
          :description => I18n.t(:tax),
          :adjustment_source => self
      })
    end
  end

  def update_totals(force_adjustment_recalculation=false)
    self.item_total       = self.line_items.total

    # save the items which might be changed by an order update, so that
    # charges can be recalculated accurately.
    self.line_items.map(&:save)

    if !self.checkout_complete || force_adjustment_recalculation
      applicable_adjustments, adjustments_to_destroy = adjustments.partition{|a| a.applicable?}
      self.adjustments = applicable_adjustments
      adjustments_to_destroy.each(&:destroy)
    end

    self.adjustment_total = self.charge_total - self.credit_total

    self.total            = self.item_total   + self.adjustment_total
  end

  def update_totals!
    update_totals

    if self.payments.total < self.total
      #Total is higher so balance_due
      self.under_paid
    elsif self.payments.total > self.total
      #Total is lower so credit_owed
      self.over_paid
    end

    save!
  end

  def update_adjustments
    self.adjustments.each(&:update_amount)
    update_totals(:force_adjustment_update)
    self
  end

  def name
    address = bill_address || ship_address
    "#{address.firstname} #{address.lastname}" if address
  end


  def out_of_stock_items
    @out_of_stock_items
  end

  def outstanding_balance
    [0, total - payments.total].max
  end

  def has_balance_outstanding?
    outstanding_balance > 0
  end

  def outstanding_credit
    [0, payments.total - total].max
  end

  def has_credit_outstanding?
    outstanding_credit > 0
  end


  def creditcards
    creditcard_ids = (payments.from_creditcard + checkout.payments.from_creditcard).map(&:source_id).uniq
    Creditcard.scoped(:conditions => {:id => creditcard_ids})
  end

  private

  def complete_order
    self.adjustments.each(&:update_amount)
    update_attribute(:completed_at, Time.now)

    if email
      OrderMailer.deliver_confirm(self)
    end

    begin
      @out_of_stock_items = InventoryUnit.sell_units(self)
      update_totals unless @out_of_stock_items.empty?
      shipment.inventory_units = inventory_units
      save!
    rescue Exception => e
      logger.error "Problem saving authorized order: #{e.message}"
      logger.error self.to_yaml
    end
  end

  def cancel_order
    restock_inventory
    OrderMailer.deliver_cancel(self)
  end

  def restock_inventory
    inventory_units.each do |inventory_unit|
      inventory_unit.restock! if inventory_unit.can_restock?
    end
  end

  def update_line_items
    to_wipe = self.line_items.select {|li| 0 == li.quantity || li.quantity.nil? }
    LineItem.destroy(to_wipe)
    self.line_items -= to_wipe      # important: remove defunct items, avoid a reload
  end

  def generate_token
    self.token = Authlogic::Random.friendly_token
  end

  def create_checkout
    self.checkout ||= Checkout.new(:order => self)
    self.checkout.enable_validation_group(:address)
    self.checkout.save!
  end

  def create_shipment
    self.shipments << Shipment.create(:order => self)
  end

end
