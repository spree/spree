require 'spree/core/validators/email'
require 'spree/order/checkout'

module Spree
  class Order < ActiveRecord::Base
    # TODO:
    # Need to use fully qualified name here because during sandbox migration
    # there is a class called Checkout which conflicts if you use this:
    #
    #   include Checkout
    #
    # rather than the qualified name. This will most likely be fixed with the
    # 1.3 release.
    include Spree::Order::Checkout
    checkout_flow do
      go_to_state :address
      go_to_state :delivery
      go_to_state :payment, if: ->(order) {
        order.update_totals
        order.payment_required?
      }
      go_to_state :confirm, if: ->(order) { order.confirmation_required? }
      go_to_state :complete
      remove_transition from: :delivery, to: :confirm
    end

    token_resource

    attr_accessible :line_items, :bill_address_attributes, :ship_address_attributes,
                    :payments_attributes, :ship_address, :bill_address, :currency,
                    :line_items_attributes, :number, :email, :use_billing, 
                    :special_instructions, :shipments_attributes, :coupon_code

    attr_reader :coupon_code

    if Spree.user_class
      belongs_to :user, class_name: Spree.user_class.to_s
      belongs_to :created_by, class_name: Spree.user_class.to_s
    else
      belongs_to :user
      belongs_to :created_by
    end

    belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address'
    alias_attribute :billing_address, :bill_address

    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
    alias_attribute :shipping_address, :ship_address

    has_many :adjustments, as: :adjustable, dependent: :destroy, order: 'created_at ASC'
    has_many :line_item_adjustments, through: :line_items, source: :adjustments
    has_many :line_items, dependent: :destroy, order: 'created_at ASC'
    has_many :payments, dependent: :destroy
    has_many :return_authorizations, dependent: :destroy
    has_many :state_changes, as: :stateful
    has_many :inventory_units

    has_many :shipments, dependent: :destroy, :class_name => "Shipment" do
      def states
        pluck(:state).uniq
      end
    end

    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :bill_address
    accepts_nested_attributes_for :ship_address
    accepts_nested_attributes_for :payments
    accepts_nested_attributes_for :shipments

    # Needs to happen before save_permalink is called
    before_validation :set_currency
    before_validation :generate_order_number, on: :create
    before_validation :clone_billing_address, if: :use_billing?
    attr_accessor :use_billing

    before_create :link_by_email
    after_create :create_tax_charge!

    validates :email, presence: true, if: :require_email
    validates :email, email: true, if: :require_email, allow_blank: true
    validate :has_available_shipment
    validate :has_available_payment

    make_permalink field: :number

    class_attribute :update_hooks
    self.update_hooks = Set.new

    def self.by_number(number)
      where(number: number)
    end

    def self.between(start_date, end_date)
      where(created_at: start_date..end_date)
    end

    def self.by_customer(customer)
      joins(:user).where("#{Spree.user_class.table_name}.email" => customer)
    end

    def self.by_state(state)
      where(state: state)
    end

    def self.complete
      where('completed_at IS NOT NULL')
    end

    def self.incomplete
      where(completed_at: nil)
    end

    # Use this method in other gems that wish to register their own custom logic
    # that should be called after Order#update
    def self.register_update_hook(hook)
      self.update_hooks.add(hook)
    end

    # For compatiblity with Calculator::PriceSack
    def amount
      line_items.inject(0.0) { |sum, li| sum + li.amount }
    end

    def currency
      self[:currency] || Spree::Config[:currency]
    end

    def display_outstanding_balance
      Spree::Money.new(outstanding_balance, { currency: currency })
    end

    def display_item_total
      Spree::Money.new(item_total, { currency: currency })
    end

    def display_adjustment_total
      Spree::Money.new(adjustment_total, { currency: currency })
    end

    def display_tax_total
      Spree::Money.new(tax_total, { currency: currency })
    end

    def display_ship_total
      Spree::Money.new(ship_total, { currency: currency })
    end

    def display_total
      Spree::Money.new(total, { currency: currency })
    end

    def to_param
      number.to_s.to_url.upcase
    end

    def completed?
      !! completed_at
    end

    # Indicates whether or not the user is allowed to proceed to checkout.
    # Currently this is implemented as a check for whether or not there is at
    # least one LineItem in the Order.  Feel free to override this logic in your
    # own application if you require additional steps before allowing a checkout.
    def checkout_allowed?
      line_items.count > 0
    end

    # Is this a free order in which case the payment step should be skipped
    def payment_required?
      total.to_f > 0.0
    end

    # If true, causes the confirmation step to happen during the checkout process
    def confirmation_required?
      if payments.empty? and Spree::Config[:always_include_confirm_step]
        true
      else
        payments.map(&:payment_method).compact.any?(&:payment_profiles_supported?)
      end
    end

    # Indicates the number of items in the order
    def item_count
      line_items.inject(0) { |sum, li| sum + li.quantity }
    end

    def backordered?
      shipments.any?(&:backordered?)
    end

    # Returns the relevant zone (if any) to be used for taxation purposes.
    # Uses default tax zone unless there is a specific match
    def tax_zone
      zone_address = Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
      Zone.match(zone_address) || Zone.default_tax
    end

    # Indicates whether tax should be backed out of the price calcualtions in
    # cases where prices include tax but the customer is not required to pay
    # taxes in that case.
    def exclude_tax?
      return false unless Spree::Config[:prices_inc_tax]
      return tax_zone != Zone.default_tax
    end

    def price_adjustments
      ActiveSupport::Deprecation.warn("Order#price_adjustments will be deprecated in Spree 2.1, please use Order#line_item_adjustments instead.")
      self.line_item_adjustments
    end

    # Array of totals grouped by Adjustment#label. Useful for displaying line item
    # adjustments on an invoice. For example, you can display tax breakout for
    # cases where tax is included in price.
    def line_item_adjustment_totals
      Hash[self.line_item_adjustments.eligible.group_by(&:label).map do |label, adjustments|
        total = adjustments.sum(&:amount)
        [label, Spree::Money.new(total, { currency: currency })]
      end]
    end

    def price_adjustment_totals
      ActiveSupport::Deprecation.warn("Order#price_adjustment_totals will be deprecated in Spree 2.1, please use Order#line_item_adjustment_totals instead.")
      self.line_item_adjustment_totals
    end

    def updater
      @updater ||= OrderUpdater.new(self)
    end

    def update!
      updater.update
    end

    def update_totals
      updater.update_totals
    end

    def clone_billing_address
      if bill_address and self.ship_address.nil?
        self.ship_address = bill_address.clone
      else
        self.ship_address.attributes = bill_address.attributes.except('id', 'updated_at', 'created_at')
      end
      true
    end

    def allow_cancel?
      return false unless completed? and state != 'canceled'
      shipment_state.nil? || %w{ready backorder pending}.include?(shipment_state)
    end

    def allow_resume?
      # we shouldn't allow resume for legacy orders b/c we lack the information
      # necessary to restore to a previous state
      return false if state_changes.empty? || state_changes.last.previous_state.nil?
      true
    end

    def awaiting_returns?
      return_authorizations.any? { |return_authorization| return_authorization.authorized? }
    end

    def contents
      @contents ||= Spree::OrderContents.new(self)
    end

    def add_variant(variant, quantity = 1, currency = nil)
      ActiveSupport::Deprecation.warn("[SPREE] Spree::Order#add_variant will be deprecated in Spree 2.1, please use order.contents.add instead.")
      contents.currency = currency unless currency.nil?
      contents.add(variant, quantity)
    end


    def remove_variant(variant, quantity = 1)
      ActiveSupport::Deprecation.warn("[SPREE] Spree::Order#remove_variant will be deprecated in Spree 2.1, please use order.contents.remove instead.")
      contents.remove(variant, quantity)
    end

    # Associates the specified user with the order.
    def associate_user!(user)
      self.user = user
      self.email = user.email
      self.created_by = user if self.created_by.blank?

      if persisted?
        # immediately persist the changes we just made, but don't use save since we might have an invalid address associated
        self.class.unscoped.where(id: id).update_all(email: user.email, user_id: user.id, created_by_id: self.created_by_id)
      end
    end

    # FIXME refactor this method and implement validation using validates_* utilities
    def generate_order_number
      record = true
      while record
        random = "R#{Array.new(9){rand(9)}.join}"
        record = self.class.where(number: random).first
      end
      self.number = random if self.number.blank?
      self.number
    end

    def shipment
      ActiveSupport::Deprecation.warn("[SPREE] Spree::Order#shipment is typically incorrect due to multiple shipments and will be deprecated in Spree 2.1, please process Spree::Order#shipments instead.")
      @shipment ||= shipments.last
    end

    def shipped_shipments
      shipments.shipped
    end

    def contains?(variant)
      find_line_item_by_variant(variant).present?
    end

    def quantity_of(variant)
      line_item = find_line_item_by_variant(variant)
      line_item ? line_item.quantity : 0
    end

    def find_line_item_by_variant(variant)
      line_items.detect { |line_item| line_item.variant_id == variant.id }
    end

    def ship_total
      adjustments.shipping.map(&:amount).sum
    end

    def tax_total
      adjustments.tax.map(&:amount).sum
    end

    # Clear shipment when transitioning to delivery step of checkout if the
    # current shipping address is not eligible for the existing shipping method
    def remove_invalid_shipments!
      shipments.each { |s| s.destroy unless s.shipping_method.available_to_order?(self) }
    end

    # Creates new tax charges if there are any applicable rates. If prices already
    # include taxes then price adjustments are created instead.
    def create_tax_charge!
      Spree::TaxRate.adjust(self)
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

    def can_ship?
      self.complete? || self.resumed? || self.awaiting_return? || self.returned?
    end

    def credit_cards
      credit_card_ids = payments.from_credit_card.pluck(:source_id).uniq
      CreditCard.scoped(conditions: { id: credit_card_ids })
    end

    # Finalizes an in progress order after checkout is complete.
    # Called after transition to complete state when payments will have been processed
    def finalize!
      touch :completed_at

      # lock all adjustments (coupon promotions, etc.)
      adjustments.update_all state: 'closed'

      # update payment and shipment(s) states, and save
      updater.update_payment_state
      shipments.each do |shipment|
        shipment.update!(self)
        shipment.finalize!
      end

      updater.update_shipment_state
      save
      updater.run_hooks

      deliver_order_confirmation_email

      self.state_changes.create({
        previous_state: 'cart',
        next_state:     'complete',
        name:           'order' ,
        user_id:        self.user_id
      }, without_protection: true)
    end

    def deliver_order_confirmation_email
      begin
        OrderMailer.confirm_email(self.id).deliver
      rescue Exception => e
        logger.error("#{e.class.name}: #{e.message}")
        logger.error(e.backtrace * "\n")
      end
    end

    # Helper methods for checkout steps
    def paid?
      payment_state == 'paid' || payment_state == 'credit_owed'
    end

    def available_payment_methods
      @available_payment_methods ||= PaymentMethod.available(:front_end)
    end

    def pending_payments
      payments.select(&:checkout?)
    end

    # processes any pending payments and must return a boolean as it's
    # return value is used by the checkout state_machine to determine
    # success or failure of the 'complete' event for the order
    #
    # Returns:
    # - true if all pending_payments processed successfully
    # - true if a payment failed, ie. raised a GatewayError
    #   which gets rescued and converted to TRUE when
    #   :allow_checkout_gateway_error is set to true
    # - false if a payment failed, ie. raised a GatewayError
    #   which gets rescued and converted to FALSE when
    #   :allow_checkout_on_gateway_error is set to false
    #
    def process_payments!
      if pending_payments.empty?
        raise Core::GatewayError.new Spree.t(:no_pending_payments)
      else
        pending_payments.each do |payment|
          break if payment_total >= total

          payment.process!

          if payment.completed?
            self.payment_total += payment.amount
          end
        end
      end
    rescue Core::GatewayError => e
      result = !!Spree::Config[:allow_checkout_on_gateway_error]
      errors.add(:base, e.message) and return result
    end

    def billing_firstname
      bill_address.try(:firstname)
    end

    def billing_lastname
      bill_address.try(:lastname)
    end

    def products
      line_items.map(&:product)
    end

    def variants
      line_items.map(&:variant)
    end

    def insufficient_stock_lines
     @insufficient_stock_lines ||= line_items.select(&:insufficient_stock?)
    end

    def merge!(order, user = nil)
      order.line_items.each do |line_item|
        next unless line_item.currency == currency
        current_line_item = self.line_items.find_by_variant_id(line_item.variant_id)
        if current_line_item
          current_line_item.quantity += line_item.quantity
          current_line_item.save
        else
          line_item.order_id = self.id
          line_item.save
        end
      end

      self.associate_user!(user) if !self.user && !user.blank?

      # So that the destroy doesn't take out line items which may have been re-assigned
      order.line_items.reload
      order.destroy
    end

    def empty!
      line_items.destroy_all
      adjustments.destroy_all
    end

    def clear_adjustments!
      self.adjustments.destroy_all
      self.line_item_adjustments.destroy_all
    end

    def has_step?(step)
      checkout_steps.include?(step)
    end

    def state_changed(name)
      state = "#{name}_state"
      if persisted?
        old_state = self.send("#{state}_was")
        self.state_changes.create({
          previous_state: old_state,
          next_state:     self.send(state),
          name:           name,
          user_id:        self.user_id
        }, without_protection: true)
      end
    end

    def coupon_code=(code)
      @coupon_code = code.strip.downcase rescue nil
    end

    # Tells us if there if the specified promotion is already associated with the order
    # regardless of whether or not its currently eligible. Useful because generally
    # you would only want a promotion action to apply to order no more than once.
    #
    # Receives an adjustment +originator+ (here a PromotionAction object) and tells
    # if the order has adjustments from that already
    def promotion_credit_exists?(originator)
      !! adjustments.includes(:originator).promotion.reload.detect { |credit| credit.originator.id == originator.id }
    end

    def promo_total
      adjustments.eligible.promotion.map(&:amount).sum
    end

    def shipped?
      %w(partial shipped).include?(shipment_state)
    end

    def create_proposed_shipments
      adjustments.shipping.delete_all
      shipments.destroy_all

      packages = Spree::Stock::Coordinator.new(self).packages
      packages.each do |package|
        shipments << package.to_shipment
      end

      shipments
    end

    # Clean shipments and make order back to address state
    #
    # At some point the might need to force the order to transition from address
    # to delivery again so that proper updated shipments are created.
    # e.g. customer goes back from payment step and changes order items 
    def ensure_updated_shipments
      if shipments.any?
        self.shipments.destroy_all
        self.update_column(:state, "address")
      end
    end

    def refresh_shipment_rates
      shipments.map &:refresh_rates
    end

    private

      def link_by_email
        self.email = user.email if self.user
      end

      # Determine if email is required (we don't want validation errors before we hit the checkout)
      def require_email
        return true unless new_record? or state == 'cart'
      end

      def ensure_line_items_present
        unless line_items.present?
          errors.add(:base, Spree.t(:there_are_no_items_for_this_order)) and return false
        end
      end

      def has_available_shipment
        return unless has_step?("delivery")
        return unless address?
        return unless ship_address && ship_address.valid?
        # errors.add(:base, :no_shipping_methods_available) if available_shipping_methods.empty?
      end

      def ensure_available_shipping_rates
        if shipments.empty? || shipments.any? { |shipment| shipment.shipping_rates.blank? }
          errors.add(:base, Spree.t(:items_cannot_be_shipped)) and return false
        end
      end

      def has_available_payment
        return unless delivery?
        # errors.add(:base, :no_payment_methods_available) if available_payment_methods.empty?
      end

      def after_cancel
        shipments.each { |shipment| shipment.cancel! }

        send_cancel_email
        self.payment_state = 'credit_owed' unless shipped?
      end

      def send_cancel_email
        OrderMailer.cancel_email(self.id).deliver
      end

      def after_resume
        shipments.each { |shipment| shipment.resume! }
      end

      def use_billing?
        @use_billing == true || @use_billing == 'true' || @use_billing == '1'
      end

      def set_currency
        self.currency = Spree::Config[:currency] if self[:currency].nil?
      end
  end
end
