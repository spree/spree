class Order < ActiveRecord::Base

  attr_accessible :line_items, :bill_address_attributes, :ship_address_attributes, :payments_attributes,
                  :ship_address, :line_items_attributes,
                  :shipping_method_id, :email, :use_billing, :special_instructions

  belongs_to :user
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :shipping_method

  has_many :state_events, :as => :stateful
  has_many :line_items, :dependent => :destroy
  has_many :inventory_units
  has_many :payments, :dependent => :destroy
  has_many :shipments, :dependent => :destroy
  has_many :return_authorizations, :dependent => :destroy
  has_many :adjustments, :dependent => :destroy

  accepts_nested_attributes_for :line_items
  accepts_nested_attributes_for :bill_address
  accepts_nested_attributes_for :ship_address
  accepts_nested_attributes_for :payments
  accepts_nested_attributes_for :shipments

  before_create :create_user
  before_create :generate_order_number

  validates_presence_of :email, :if => :require_email
  validate :has_available_shipment

  #delegate :ip_address, :to => :checkout
  def ip_address
    '192.168.1.100'
  end

  scope :by_number, lambda {|number| where("orders.number = ?", number)}
  scope :between, lambda {|*dates| where("orders.created_at between ? and ?", dates.first.to_date, dates.last.to_date)}
  scope :by_customer, lambda {|customer| joins(:user).where("users.email =?", customer)}
  scope :by_state, lambda {|state| where("state = ?", state)}
  scope :complete, where("orders.completed_at IS NOT NULL")
  scope :incomplete, where("orders.completed_at IS NULL")

  make_permalink :field => :number

  attr_accessor :out_of_stock_items

  class_attribute :update_hooks
  self.update_hooks = Set.new

  # Use this method in other gems that wish to register their own custom logic that should be called after Order#updat
  def self.register_update_hook(hook)
    self.update_hooks.add(hook)
  end

  def to_param
    number.to_s.parameterize.upcase
  end

  def completed?
    !! completed_at
  end

  # Indicates whether or not the user is allowed to proceed to checkout.  Currently this is implemented as a
  # check for whether or not there is at least one LineItem in the Order.  Feel free to override this logic
  # in your own application if you require additional steps before allowing a checkout.
  def checkout_allowed?
    line_items.count > 0
  end

  # Indicates the number of items in the order
  def item_count
    line_items.map(&:quantity).sum
  end

  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'cart', :use_transactions => false do

    event :next do
      transition :from => 'cart',     :to => 'address'
      transition :from => 'address',  :to => 'delivery'
      transition :from => 'delivery', :to => 'payment'
      transition :from => 'confirm',  :to => 'complete'

      # note: some payment methods will not support a confirm step
      transition :from => 'payment',  :to => 'confirm',
                                      :if => Proc.new { Gateway.current && Gateway.current.payment_profiles_supported? }

      transition :from => 'payment', :to => 'complete'
    end

    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end
    event :return do
      transition :to => 'returned', :from => 'awaiting_return'
    end
    event :resume do
      transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
    end
    event :authorize_return do
      transition :to => 'awaiting_return'
    end

    before_transition :to => 'complete' do |order|
      begin
        order.process_payments!
      rescue Spree::GatewayError
        if Spree::Config[:allow_checkout_on_gateway_error]
          true
        else
          false
        end
      end
    end

    after_transition :to => 'complete', :do => :finalize!
    after_transition :to => 'delivery', :do => :create_tax_charge!
    after_transition :to => 'payment', :do => :create_shipment!
    after_transition :to => 'canceled', :do => :after_cancel

  end

  # Indicates whether there are any backordered InventoryUnits associated with the Order.
  def backordered?
    return false unless Spree::Config[:track_inventory_levels]
    inventory_units.backorder.present?
  end

  # This is a multi-purpose method for processing logic related to changes in the Order.  It is meant to be called from
  # various observers so that the Order is aware of changes that affect totals and other values stored in the Order.
  # This method should never do anything to the Order that results in a save call on the object (otherwise you will end
  # up in an infinite recursion as the associations try to save and then in turn try to call +update!+ again.)
  def update!
    update_totals
    update_payment_state

    # give each of the shipments a chance to update themselves
    shipments.each { |shipment| shipment.update!(self) }#(&:update!)
    update_shipment_state
    update_adjustments
    # update totals a second time in case updated adjustments have an effect on the total
    update_totals

    update_attributes_without_callbacks({
      :payment_state => payment_state,
      :shipment_state => shipment_state,
      :item_total => item_total,
      :adjustment_total => adjustment_total,
      :payment_total => payment_total,
      :total => total
    })

    #ensure checkout payment always matches order total
    if payment and payment.checkout? and payment.amount != total
      payment.update_attributes_without_callbacks(:amount => total)
    end

    update_hooks.each { |hook| self.send hook }
  end

  def restore_state
    # pop the resume event so we can see what the event before that was
    state_events.pop if state_events.last.name == "resume"
    update_attribute("state", state_events.last.previous_state)

    if paid?
      raise "do something with inventory"
      #InventoryUnit.assign_opening_inventory(self) if inventory_units.empty?
      #shipment.inventory_units = inventory_units
      #shipment.ready!
    end

  end

  before_validation :clone_billing_address, :if => "@use_billing"
  attr_accessor :use_billing

  def clone_billing_address
    if bill_address and self.ship_address.nil?
      self.ship_address = bill_address.clone
    else
      self.ship_address.attributes = bill_address.attributes.except("id", "updated_at", "created_at")
    end
    true
  end



  def allow_cancel?
    return false unless completed? and state != 'canceled'
    %w{ready backorder pending}.include? shipment_state
  end

  def allow_resume?
    # we shouldn't allow resume for legacy orders b/c we lack the information necessary to restore to a previous state
    return false if state_events.empty? || state_events.last.previous_state.nil?
    true
  end

  def add_variant(variant, quantity = 1)
    current_item = contains?(variant)
    if current_item
      current_item.quantity += quantity
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

  # FIXME refactor this method and implement validation using validates_* utilities
  def generate_order_number
    record = true
    while record
      random = "R#{Array.new(9){rand(9)}.join}"
      record = self.class.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random if self.number.blank?
    self.number
  end

  # convenience method since many stores will not allow user to create multiple shipments
  def shipment
    @shipment ||= shipments.last
  end

  def contains?(variant)
    line_items.detect{|line_item| line_item.variant_id == variant.id}
  end

  def ship_total
    adjustments.shipping.map(&:amount).sum
  end

  def tax_total
    adjustments.tax.map(&:amount).sum
  end

  # Creates a new tax charge if applicable.  Uses the highest possible matching rate and destroys any previous
  # tax charges if they were created by rates that no longer apply.
  def create_tax_charge!
    adjustments.tax.each {|e| e.destroy }
    TaxRate.match(ship_address).each {|r| r.create_adjustment(I18n.t(:tax), self, self, true) }
  end

  # Creates a new shipment (adjustment is created by shipment model)
  def create_shipment!
    shipping_method.reload
    if shipment.present?
      shipment.update_attributes(:shipping_method => shipping_method)
    else
      self.shipments << Shipment.create(:order => self,
                                        :shipping_method => shipping_method,
                                        :address => self.ship_address)
    end

  end

  def outstanding_balance
    total - payment_total
  end

  def outstanding_balance?
   self.outstanding_balance != 0
  end

  def name
    if (address = bill_address || ship_address)
      "#{address.firstname} #{address.lastname}"
    end
  end

  def creditcards
    creditcard_ids = payments.from_creditcard.map(&:source_id).uniq
    Creditcard.scoped(:conditions => {:id => creditcard_ids})
  end

  def process_payments!
    ret = payments.each(&:process!)
  end

  # Finalizes an in progress order after checkout is complete.
  # Called after transition to complete state when payments will have been processed
  def finalize!
    update_attribute(:completed_at, Time.now)
    self.out_of_stock_items = InventoryUnit.assign_opening_inventory(self)
    # lock any optional adjustments (coupon promotions, etc.)
    adjustments.optional.each { |adjustment| adjustment.update_attribute("locked", true) }
    OrderMailer.confirm_email(self).deliver

    self.state_events.create({
      :previous_state => "cart",
      :next_state     => "complete",
      :name           => "order" ,
      :user_id        => (User.respond_to?(:current) && User.current.try(:id)) || self.user_id
    })
  end


  # Helper methods for checkout steps

  def available_shipping_methods(display_on = nil)
    return [] unless ship_address
    ShippingMethod.all_available(self, display_on)
  end

  def rate_hash
    @rate_hash ||= available_shipping_methods(:front_end).collect do |ship_method|
      next unless cost = ship_method.calculator.compute(self)
      { :id => ship_method.id,
        :shipping_method => ship_method,
        :name => ship_method.name,
        :cost => cost
      }
    end.compact.sort_by{|r| r[:cost]}
  end

  def payment
    payments.first
  end

  def available_payment_methods
    @available_payment_methods ||= PaymentMethod.available(:front_end)
  end

  def payment_method
    if payment and payment.payment_method
      payment.payment_method
    else
      available_payment_methods.first
    end
  end

  def billing_firstname
    bill_address.try(:firstname)
  end

  def billing_lastname
    bill_address.try(:lastname)
  end

  def products
    line_items.map{|li| li.variant.product}
  end

  private
  def create_user
    self.email = user.email if self.user and not user.anonymous?
    self.user ||= User.anonymous!
  end

  # Updates the +shipment_state+ attribute according to the following logic:
  #
  # shipped   when all Shipments are in the "shipped" state
  # partial   when at least one Shipment has a state of "shipped" and there is another Shipment with a state other than "shipped"
  #           or there are InventoryUnits associated with the order that have a state of "sold" but are not associated with a Shipment.
  # ready     when all Shipments are in the "ready" state
  # backorder when there is backordered inventory associated with an order
  # pending   when all Shipments are in the "pending" state
  #
  # The +shipment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
  def update_shipment_state
    self.shipment_state =
    case shipments.count
    when 0
      nil
    when shipments.shipped.count
      "shipped"
    when shipments.ready.count
      "ready"
    when shipments.pending.count
      "pending"
    else
      "partial"
    end
    self.shipment_state = "backorder" if backordered?

    if old_shipment_state = self.changed_attributes["shipment_state"]
      self.state_events.create({
        :previous_state => old_shipment_state,
        :next_state     => self.shipment_state,
        :name           => "shipment" ,
        :user_id        => (User.respond_to?(:current) && User.current && User.current.id) || self.user_id
      })
    end

  end

  # Updates the +payment_state+ attribute according to the following logic:
  #
  # paid          when +payment_total+ is equal to +total+
  # balance_due   when +payment_total+ is less than +total+
  # credit_owed   when +payment_total+ is greater than +total+
  # failed        when most recent payment is in the failed state
  #
  # The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
  def update_payment_state
    if payment_total < total
      self.payment_state = "balance_due"
      self.payment_state = "failed" if payments.present? and payments.last.state == "failed"
    elsif payment_total > total
      self.payment_state = "credit_owed"
    else
      self.payment_state = "paid"
    end

    if old_payment_state = self.changed_attributes["payment_state"]
      self.state_events.create({
        :previous_state => old_payment_state,
        :next_state     => self.payment_state,
        :name           => "payment" ,
        :user_id        =>  (User.respond_to?(:current) && User.current && User.current.id) || self.user_id
      })
    end
  end

  # Updates the following Order total values:
  #
  # +payment_total+      The total value of all finalized Payments (NOTE: non-finalized Payments are excluded)
  # +item_total+         The total value of all LineItems
  # +adjustment_total+   The total value of all adjustments (promotions, credits, etc.)
  # +total+              The so-called "order total."  This is equivalent to +item_total+ plus +adjustment_total+.
  def update_totals
    # update_adjustments
    self.payment_total = payments.completed.map(&:amount).sum
    self.item_total = line_items.map(&:amount).sum
    self.adjustment_total = adjustments.eligible.map(&:amount).sum
    self.total = item_total + adjustment_total
  end

  # Updates each of the Order adjustments.  This is intended to be called from an Observer so that the Order can
  # respond to external changes to LineItem, Shipment, other Adjustments, etc.
  # Adjustments will check if they are still eligible. Ineligible adjustments are preserved but not counted
  # towards adjustment_total.
  def update_adjustments
    self.adjustments.reload.each(&:update!)
  end

  # Determine if email is required (we don't want validation errors before we hit the checkout)
  def require_email
    return true unless new_record? or state == 'cart'
  end

  def has_available_shipment
    return unless :address == state_name.to_sym
    return unless ship_address && ship_address.valid?
    errors.add(:base, :no_shipping_methods_available) if available_shipping_methods.empty?
  end

  def after_cancel
    # TODO: make_shipments_pending
    # TODO: restock_inventory
    OrderMailer.cancel_email(self).deliver
  end

end
