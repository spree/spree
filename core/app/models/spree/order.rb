require 'spree/core/validators/email'
require 'spree/order/checkout'

module Spree
  class Order < ActiveRecord::Base
    include Spree::Order::Checkout
    include Spree::Order::CurrencyUpdater

    checkout_flow do
      go_to_state :address
      go_to_state :delivery
      go_to_state :payment, if: ->(order) { order.payment_required? }
      go_to_state :confirm, if: ->(order) { order.confirmation_required? }
      go_to_state :complete
      remove_transition from: :delivery, to: :confirm
    end

    token_resource

    attr_reader :coupon_code

    if Spree.user_class
      belongs_to :user, class_name: Spree.user_class.to_s
      belongs_to :created_by, class_name: Spree.user_class.to_s
      belongs_to :approver, class_name: Spree.user_class.to_s
    else
      belongs_to :user
      belongs_to :created_by
      belongs_to :approver
    end

    belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address'
    alias_attribute :billing_address, :bill_address

    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
    alias_attribute :shipping_address, :ship_address

    alias_attribute :ship_total, :shipment_total

    has_many :state_changes, as: :stateful
    has_many :line_items, -> { order("#{LineItem.table_name}.created_at ASC") }, dependent: :destroy, inverse_of: :order
    has_many :payments, dependent: :destroy
    has_many :return_authorizations, dependent: :destroy, inverse_of: :order
    has_many :adjustments, -> { order("#{Adjustment.table_name}.created_at ASC") }, as: :adjustable, dependent: :destroy
    has_many :line_item_adjustments, through: :line_items, source: :adjustments
    has_many :shipment_adjustments, through: :shipments, source: :adjustments
    has_many :inventory_units, inverse_of: :order
    has_many :products, through: :variants
    has_many :variants, through: :line_items

    has_and_belongs_to_many :promotions, join_table: 'spree_orders_promotions'

    has_many :shipments, dependent: :destroy, inverse_of: :order do
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
    before_update :homogenize_line_item_currencies, if: :currency_changed?

    validates :email, presence: true, if: :require_email
    validates :email, email: true, if: :require_email, allow_blank: true
    validates :number, uniqueness: true
    validate :has_available_shipment

    make_permalink field: :number

    delegate :update_totals, :persist_totals, :to => :updater

    class_attribute :update_hooks
    self.update_hooks = Set.new

    def self.by_number(number)
      where(number: number)
    end

    scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :completed_between, ->(start_date, end_date) { where(completed_at: start_date..end_date) }
    scope :reverse_chronological, -> { order(created_at: :desc) }

    def self.between(start_date, end_date)
      ActiveSupport::Deprecation.warn("Order#between will be deprecated in Spree 2.3, please use either Order#created_between or Order#completed_between instead.")
      self.created_between(start_date, end_date)
    end

    def self.by_customer(customer)
      joins(:user).where("#{Spree.user_class.table_name}.email" => customer)
    end

    def self.by_state(state)
      where(state: state)
    end

    def self.complete
      where.not(completed_at: nil)
    end

    def self.incomplete
      where(completed_at: nil)
    end

    # Use this method in other gems that wish to register their own custom logic
    # that should be called after Order#update
    def self.register_update_hook(hook)
      self.update_hooks.add(hook)
    end

    def all_adjustments
      Adjustment.where("order_id = :order_id OR (adjustable_id = :order_id AND adjustable_type = 'Spree::Order')",
        order_id: self.id)
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

    def display_included_tax_total
      Spree::Money.new(included_tax_total, { currency: currency })
    end

    def display_additional_tax_total
      Spree::Money.new(additional_tax_total, { currency: currency })
    end

    def display_tax_total
      Spree::Money.new(included_tax_total + additional_tax_total, { currency: currency })
    end

    def display_shipment_total
      Spree::Money.new(shipment_total, { currency: currency })
    end
    alias :display_ship_total :display_shipment_total

    def display_total
      Spree::Money.new(total, { currency: currency })
    end

    def shipping_discount
      shipment_adjustments.eligible.sum(:amount) * - 1
    end

    def to_param
      number.to_s.to_url.upcase
    end

    def completed?
      completed_at.present?
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
      Spree::Config[:always_include_confirm_step] ||
        payments.valid.map(&:payment_method).compact.any?(&:payment_profiles_supported?) ||
        # Little hacky fix for #4117
        # If this wasn't here, order would transition to address state on confirm failure
        # because there would be no valid payments any more.
        state == 'confirm'
    end

    def backordered?
      shipments.any?(&:backordered?)
    end

    # Returns the relevant zone (if any) to be used for taxation purposes.
    # Uses default tax zone unless there is a specific match
    def tax_zone
      @tax_zone ||= Zone.match(tax_address) || Zone.default_tax
    end

    # Indicates whether tax should be backed out of the price calcualtions in
    # cases where prices include tax but the customer is not required to pay
    # taxes in that case.
    def exclude_tax?
      return false unless Spree::Config[:prices_inc_tax]
      tax_zone != Zone.default_tax
    end

    # Returns the address for taxation based on configuration
    def tax_address
      Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
    end

    def updater
      @updater ||= OrderUpdater.new(self)
    end

    def update!
      updater.update
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

    def awaiting_returns?
      return_authorizations.any? { |return_authorization| return_authorization.authorized? }
    end

    def contents
      @contents ||= Spree::OrderContents.new(self)
    end

    # Associates the specified user with the order.
    def associate_user!(user, override_email = true)
      self.user = user
      attrs_to_set = { user_id: user.id }
      attrs_to_set[:email] = user.email if override_email
      attrs_to_set[:created_by_id] = user.id if self.created_by.blank?
      assign_attributes(attrs_to_set)

      if persisted?
        # immediately persist the changes we just made, but don't use save since we might have an invalid address associated
        self.class.unscoped.where(id: id).update_all(attrs_to_set)
      end
    end

    def generate_order_number(digits = 9)
      self.number ||= loop do
         # Make a random number.
         random = "R#{Array.new(digits){rand(10)}.join}"
         # Use the random  number if no other order exists with it.
         if self.class.exists?(number: random)
           # If over half of all possible options are taken add another digit.
           digits += 1 if self.class.count > (10 ** digits / 2)
         else
           break random
         end
       end
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

    # Creates new tax charges if there are any applicable rates. If prices already
    # include taxes then price adjustments are created instead.
    def create_tax_charge!
      Spree::TaxRate.adjust(self, line_items)
      Spree::TaxRate.adjust(self, shipments) if shipments.any?
    end

    def outstanding_balance
      if self.state == 'canceled' && self.payments.present? && self.payments.completed.size > 0
        -1 * payment_total
      else
        total - payment_total
      end
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
      CreditCard.where(id: credit_card_ids)
    end

    # Finalizes an in progress order after checkout is complete.
    # Called after transition to complete state when payments will have been processed
    def finalize!
      # lock all adjustments (coupon promotions, etc.)
      all_adjustments.each{|a| a.close}

      # update payment and shipment(s) states, and save
      updater.update_payment_state
      shipments.each do |shipment|
        shipment.update!(self)
        shipment.finalize!
      end

      updater.update_shipment_state
      save
      updater.run_hooks

      touch :completed_at

      deliver_order_confirmation_email unless confirmation_delivered?

      consider_risk
    end

    def fulfill!
      shipments.each { |shipment| shipment.update!(self) if shipment.persisted? }
      updater.update_shipment_state
      save!
    end

    def deliver_order_confirmation_email
      OrderMailer.confirm_email(self.id).deliver
      update_column(:confirmation_delivered, true)
    end

    # Helper methods for checkout steps
    def paid?
      payment_state == 'paid' || payment_state == 'credit_owed'
    end

    def available_payment_methods
      @available_payment_methods ||= (PaymentMethod.available(:front_end) + PaymentMethod.available(:both)).uniq
    end

    def pending_payments
      payments.select { |payment| payment.checkout? || payment.pending? }
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

    def insufficient_stock_lines
     line_items.select(&:insufficient_stock?)
    end

    def ensure_line_items_are_in_stock
      if insufficient_stock_lines.present?
        errors.add(:base, Spree.t(:insufficient_stock_lines_present)) and return false
      end
    end

    def merge!(order, user = nil)
      order.line_items.each do |line_item|
        next unless line_item.currency == currency
        current_line_item = self.line_items.find_by(variant: line_item.variant)

        if current_line_item
          current_line_item.quantity += line_item.quantity
          current_line_item.save
        else
          line_item.order_id = self.id
          line_item.save
        end
      end

      self.associate_user!(user) if !self.user && !user.blank?

      updater.update_item_count
      updater.update_item_total
      updater.persist_totals

      # So that the destroy doesn't take out line items which may have been re-assigned
      order.line_items.reload
      order.destroy
    end

    def empty!
      line_items.destroy_all
      updater.update_item_count
      adjustments.destroy_all
      shipments.destroy_all

      update_totals
      persist_totals
    end

    def has_step?(step)
      checkout_steps.include?(step)
    end

    def state_changed(name)
      state = "#{name}_state"
      if persisted?
        old_state = self.send("#{state}_was")
        new_state = self.send(state)
        unless old_state == new_state
          self.state_changes.create(
            previous_state: old_state,
            next_state:     new_state,
            name:           name,
            user_id:        self.user_id
          )
        end
      end
    end

    def coupon_code=(code)
      @coupon_code = code.strip.downcase rescue nil
    end

    def can_add_coupon?
      Spree::Promotion.order_activatable?(self)
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

    def apply_free_shipping_promotions
      Spree::PromotionHandler::FreeShipping.new(self).activate
      shipments.each { |shipment| ItemAdjustments.new(shipment).update }
      updater.update_shipment_total
      persist_totals
    end

    # Clean shipments and make order back to address state
    #
    # At some point the might need to force the order to transition from address
    # to delivery again so that proper updated shipments are created.
    # e.g. customer goes back from payment step and changes order items
    def ensure_updated_shipments
      if shipments.any? && !self.completed?
        self.shipments.destroy_all
        self.update_column(:shipment_total, 0)
        restart_checkout_flow
      end
    end

    def restart_checkout_flow
      self.update_columns(
        state: checkout_steps.first,
        updated_at: Time.now,
      )
    end

    def refresh_shipment_rates
      shipments.map &:refresh_rates
    end

    def shipping_eq_billing_address?
      (bill_address.empty? && ship_address.empty?) || bill_address.same_as?(ship_address)
    end

    def set_shipments_cost
      shipments.each(&:update_amounts)
      updater.update_shipment_total
      persist_totals
    end

    def is_risky?
      self.payments.risky.count > 0
    end

    def approved_by(user)
      self.transaction do
        approve!
        self.update_columns(
          approver_id: user.id,
          approved_at: Time.now,
          considered_risky: false,
        )
      end
    end

    def approved?
      !!self.approved_at
    end

    def can_approve?
      !approved?
    end

    def consider_risk
      if is_risky? && !approved?
        considered_risky!
      end
    end

    def considered_risky!
      update_column(:considered_risky, true)
    end

    def approve!
      update_column(:considered_risky, false)
    end

    # moved from api order_decorator. This is a better place for it.
    def update_line_items(line_item_params)
      return if line_item_params.blank?
      line_item_params.each_value do |attributes|
        if attributes[:id].present?
          self.line_items.find(attributes[:id]).update_attributes!(attributes)
        else
          self.line_items.create!(attributes)
        end
      end
      self.ensure_updated_shipments
    end

    def reload(options=nil)
      remove_instance_variable(:@tax_zone) if defined?(@tax_zone)
      super
    end

    private

      def link_by_email
        self.email = user.email if self.user
      end

      # Determine if email is required (we don't want validation errors before we hit the checkout)
      def require_email
        true unless new_record? or ['cart', 'address'].include?(state)
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

      def after_cancel
        shipments.each { |shipment| shipment.cancel! }
        payments.completed.each { |payment| payment.cancel! }
        send_cancel_email
        self.update!
      end

      def send_cancel_email
        OrderMailer.cancel_email(self.id).deliver
      end

      def after_resume
        shipments.each { |shipment| shipment.resume! }
        consider_risk
      end

      def use_billing?
        @use_billing == true || @use_billing == 'true' || @use_billing == '1'
      end

      def set_currency
        self.currency = Spree::Config[:currency] if self[:currency].nil?
      end

  end
end
