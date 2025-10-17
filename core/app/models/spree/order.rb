require_dependency 'spree/order/checkout'
require_dependency 'spree/order/currency_updater'
require_dependency 'spree/order/digital'
require_dependency 'spree/order/payments'
require_dependency 'spree/order/store_credit'
require_dependency 'spree/order/emails'
require_dependency 'spree/order/gift_card'

module Spree
  class Order < Spree.base_class
    PAYMENT_STATES = %w(balance_due credit_owed failed paid void)
    SHIPMENT_STATES = %w(backorder canceled partial pending ready shipped)
    LINE_ITEM_REMOVABLE_STATES = %w(cart address delivery payment confirm resumed)

    extend Spree::DisplayMoney

    include Spree::Order::Checkout
    include Spree::Order::CurrencyUpdater
    include Spree::Order::Digital
    include Spree::Order::Payments
    include Spree::Order::StoreCredit
    include Spree::Order::AddressBook
    include Spree::Order::Emails
    include Spree::Order::Webhooks
    include Spree::Core::NumberGenerator.new(prefix: 'R')
    include Spree::Order::GiftCard

    include Spree::NumberIdentifier
    include Spree::NumberAsParam
    include Spree::SingleStoreResource
    include Spree::MemoizedData
    include Spree::Metafields
    include Spree::Metadata
    include Spree::MultiSearchable
    if defined?(Spree::Security::Orders)
      include Spree::Security::Orders
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end

    has_secure_token :token, length: 35

    MEMOIZED_METHODS = %w(tax_zone)

    money_methods :outstanding_balance, :item_total,           :adjustment_total,
                  :included_tax_total,  :additional_tax_total, :tax_total,
                  :shipment_total,      :promo_total,          :total,
                  :cart_promo_total,    :pre_tax_item_amount,  :pre_tax_total,
                  :payment_total

    alias display_ship_total display_shipment_total
    alias_attribute :ship_total, :shipment_total

    MONEY_THRESHOLD  = 100_000_000
    MONEY_VALIDATION = {
      presence: true,
      numericality: {
        greater_than: -MONEY_THRESHOLD,
        less_than: MONEY_THRESHOLD,
        allow_blank: true
      },
      format: { with: /\A-?\d+(?:\.\d{1,2})?\z/, allow_blank: true }
    }.freeze

    POSITIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
      validation.fetch(:numericality)[:greater_than_or_equal_to] = 0
    end.freeze

    NEGATIVE_MONEY_VALIDATION = MONEY_VALIDATION.deep_dup.tap do |validation|
      validation.fetch(:numericality)[:less_than_or_equal_to] = 0
    end.freeze

    checkout_flow do
      go_to_state :address
      go_to_state :delivery, if: ->(order) { order.delivery_required? }
      go_to_state :payment, if: ->(order) { order.payment? || order.payment_required? }
      go_to_state :confirm, if: ->(order) { order.confirmation_required? }
      go_to_state :complete
      remove_transition from: :delivery, to: :confirm, unless: ->(order) { order.confirmation_required? }
    end

    self.whitelisted_ransackable_associations = %w[shipments user created_by approver canceler promotions bill_address ship_address line_items store]
    self.whitelisted_ransackable_attributes = %w[
      completed_at email number state payment_state shipment_state
      total item_total item_count considered_risky channel
    ]
    self.whitelisted_ransackable_scopes = %w[refunded partially_refunded multi_search]

    attr_reader :coupon_code
    attr_accessor :temporary_address, :temporary_credit_card

    attribute :state_machine_resumed, :boolean

    acts_as_taggable_on :tags
    acts_as_taggable_tenant :store_id

    ASSOCIATED_USER_ATTRIBUTES = [:user_id, :email, :created_by_id, :bill_address_id, :ship_address_id]

    belongs_to :user, class_name: "::#{Spree.user_class}", optional: true, autosave: true
    belongs_to :created_by, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :approver, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :canceler, class_name: "::#{Spree.admin_user_class}", optional: true

    belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address',
                              optional: true, dependent: :destroy
    alias_method :billing_address, :bill_address
    alias_method :billing_address=, :bill_address=

    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address',
                              optional: true, dependent: :destroy
    alias_method :shipping_address, :ship_address
    alias_method :shipping_address=, :ship_address=

    belongs_to :store, class_name: 'Spree::Store'

    with_options dependent: :destroy do
      has_many :state_changes, as: :stateful, class_name: 'Spree::StateChange'
      has_many :line_items, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::LineItem'
      has_many :payments, class_name: 'Spree::Payment'
      has_many :return_authorizations, inverse_of: :order, class_name: 'Spree::ReturnAuthorization'
      has_many :adjustments, -> { order(:created_at) }, as: :adjustable, class_name: 'Spree::Adjustment'
    end
    has_many :reimbursements, inverse_of: :order, class_name: 'Spree::Reimbursement'
    has_many :customer_returns, class_name: 'Spree::CustomerReturn', through: :return_authorizations
    has_many :line_item_adjustments, through: :line_items, source: :adjustments
    has_many :inventory_units, inverse_of: :order, class_name: 'Spree::InventoryUnit'
    has_many :return_items, through: :inventory_units, class_name: 'Spree::ReturnItem'
    has_many :variants, through: :line_items
    has_many :products, through: :variants
    has_many :refunds, through: :payments
    has_many :all_adjustments,
             class_name: 'Spree::Adjustment',
             foreign_key: :order_id,
             dependent: :destroy,
             inverse_of: :order

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :promotions, through: :order_promotions, class_name: 'Spree::Promotion'

    has_many :shipments, class_name: 'Spree::Shipment', dependent: :destroy, inverse_of: :order do
      def states
        pluck(:state).uniq
      end
    end
    has_many :shipment_adjustments, through: :shipments, source: :adjustments

    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :bill_address
    accepts_nested_attributes_for :ship_address
    accepts_nested_attributes_for :payments, reject_if: :credit_card_nil_payment?
    accepts_nested_attributes_for :shipments

    # Needs to happen before save_permalink is called
    before_validation :ensure_store_presence
    before_validation :ensure_currency_presence

    before_validation :clone_billing_address, if: :use_billing?
    before_validation :clone_shipping_address, if: :use_shipping?
    attr_accessor :use_billing, :use_shipping

    before_create :link_by_email
    before_update :ensure_updated_shipments, :homogenize_line_item_currencies, if: :currency_changed?

    with_options presence: true do
      # we want to have this case_sentive: true as changing it to false causes all SQL to use LOWER(slug)
      # which is very costly and slow on large set of records
      validates :email, length: { maximum: 254, allow_blank: true }, email: { allow_blank: true }, if: :require_email
      validates :item_count, numericality: { greater_than_or_equal_to: 0, less_than: 2**31, only_integer: true, allow_blank: true }
      validates :store
      validates :currency
    end
    validates :payment_state,        inclusion:    { in: PAYMENT_STATES, allow_blank: true }
    validates :shipment_state,       inclusion:    { in: SHIPMENT_STATES, allow_blank: true }
    validates :item_total,           POSITIVE_MONEY_VALIDATION
    validates :adjustment_total,     MONEY_VALIDATION
    validates :included_tax_total,   POSITIVE_MONEY_VALIDATION
    validates :additional_tax_total, POSITIVE_MONEY_VALIDATION
    validates :payment_total,        MONEY_VALIDATION
    validates :shipment_total,       MONEY_VALIDATION
    validates :promo_total,          NEGATIVE_MONEY_VALIDATION
    validates :total,                MONEY_VALIDATION

    delegate :update_totals, :persist_totals, to: :updater
    delegate :merge!, to: :merger
    delegate :firstname, :lastname, to: :bill_address, prefix: true, allow_nil: true

    class_attribute :update_hooks
    self.update_hooks = Set.new

    scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :completed_between, ->(start_date, end_date) { where(completed_at: start_date..end_date) }
    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }
    scope :canceled, -> { where(state: %w[canceled partially_canceled]) }
    scope :not_canceled, -> { where.not(state: %w[canceled partially_canceled]) }
    scope :ready_to_ship, -> { where(shipment_state: %w[ready pending]) }
    scope :partially_shipped, -> { where(shipment_state: %w[partial]) }
    scope :not_shipped, -> { where(shipment_state: %w[ready pending partial]) }
    scope :shipped, -> { where(shipment_state: %w[shipped]) }
    scope :refunded, lambda {
      joins(:refunds).group(:id).having("sum(#{Spree::Refund.table_name}.amount) = #{Spree::Order.table_name}.total")
    }
    scope :partially_refunded, lambda {
                                joins(:refunds).group(:id).having("sum(#{Spree::Refund.table_name}.amount) < #{Spree::Order.table_name}.total")
                              }
    scope :with_deleted_bill_address, -> { joins(:bill_address).where.not(Address.table_name => { deleted_at: nil }) }
    scope :with_deleted_ship_address, -> { joins(:ship_address).where.not(Address.table_name => { deleted_at: nil }) }

    # shows completed orders first, by their completed_at date, then uncompleted orders by their created_at
    scope :reverse_chronological, -> { order(Arel.sql('spree_orders.completed_at IS NULL'), completed_at: :desc, created_at: :desc) }

    def self.multi_search(query)
      sanitized_query = sanitize_query_for_multi_search(query)
      return none if query.blank?

      query_pattern = "%#{sanitized_query}%"

      conditions = []
      conditions << arel_table[:number].lower.matches(query_pattern)

      conditions << multi_search_condition(Spree::Address, :firstname, sanitized_query)
      conditions << multi_search_condition(Spree::Address, :lastname, sanitized_query)

      full_name = NameOfPerson::PersonName.full(sanitized_query)

      if full_name.first.present? && full_name.last.present?
        conditions << multi_search_condition(Spree::Address, :firstname, full_name.first)
        conditions << multi_search_condition(Spree::Address, :lastname, full_name.last)
      end

      left_joins(:bill_address).where(arel_table[:email].lower.eq(query.downcase)).or(where(conditions.reduce(:or)))
    end

    # Use this method in other gems that wish to register their own custom logic
    # that should be called after Order#update
    def self.register_update_hook(hook)
      update_hooks.add(hook)
    end

    # For compatibility with Calculator::PriceSack
    def amount
      line_items.inject(0.0) { |sum, li| sum + li.amount }
    end

    # Sum of all line item amounts pre-tax
    def pre_tax_item_amount
      line_items.sum(:pre_tax_amount)
    end

    # Sum of all line item and shipment pre-tax
    def pre_tax_total
      pre_tax_item_amount + shipments.sum(:pre_tax_amount)
    end

    # Returns the subtotal used for analytics integrations
    # It's a sum of the item total and the promo total
    # @return [Float]
    def analytics_subtotal
      (item_total + line_items.sum(:promo_total)).to_f
    end

    def shipping_discount
      shipment_adjustments.non_tax.eligible.sum(:amount) * - 1
    end

    def completed?
      completed_at.present?
    end

    def order_refunded?
      (payment_state.in?(%w[void failed]) && refunds.sum(:amount).positive?) ||
        refunds.sum(:amount) == total_minus_store_credits - additional_tax_total.abs
    end

    def partially_refunded?
      return false if refunds.empty? || payment_state.in?(%w[void failed])

      refunds.sum(:amount) < total_minus_store_credits - additional_tax_total.abs
    end

    # Indicates whether or not the user is allowed to proceed to checkout.
    # Currently this is implemented as a check for whether or not there is at
    # least one LineItem in the Order.  Feel free to override this logic in your
    # own application if you require additional steps before allowing a checkout.
    def checkout_allowed?
      line_items.exists?
    end

    # Does this order require a delivery (physical or digital).
    def delivery_required?
      true # true for Spree, can be decorated
    end

    # Is this a free order in which case the payment step should be skipped
    def payment_required?
      total.to_f > 0.0
    end

    # If true, causes the confirmation step to happen during the checkout process
    def confirmation_required?
      Spree::Config[:always_include_confirm_step] ||
        payments.valid.map(&:payment_method).compact.any?(&:confirmation_required?) ||
        # Little hacky fix for #4117
        # If this wasn't here, order would transition to address state on confirm failure
        # because there would be no valid payments any more.
        confirm?
    end

    def email_required?
      require_email
    end

    def backordered?
      shipments.any?(&:backordered?)
    end

    # Check if the shipping address is a quick checkout address
    # quick checkout addresses are incomplete as wallet providers like Apple Pay and Google Pay
    # do not provide all the address fields until the checkout is completed (confirmed) on their side
    # @return [Boolean]
    def quick_checkout?
      shipping_address.present? && shipping_address.quick_checkout?
    end

    # Check if quick checkout is available for this order
    # Either fully digital or not digital at all
    # @return [Boolean]
    def quick_checkout_available?
      payment_required? && shipments.count <= 1 && (digital? || !some_digital? || !delivery_required?)
    end

    # Check if quick checkout requires an address collection
    # If the order is digital or not delivery required, then we don't need to collect an address
    # @return [Boolean]
    def quick_checkout_require_address?
      !digital? && delivery_required?
    end

    # Returns the relevant zone (if any) to be used for taxation purposes.
    # Uses default tax zone unless there is a specific match
    def tax_zone
      @tax_zone ||= Zone.match(tax_address) || Zone.default_tax
    end

    # Returns the address for taxation based on configuration
    def tax_address
      Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
    end

    def updater
      @updater ||= Spree::Dependencies.order_updater.constantize.new(self)
    end

    def update_with_updater!
      updater.update
    end

    def merger
      @merger ||= Spree::OrderMerger.new(self)
    end

    def ensure_store_presence
      self.store ||= Spree::Store.default
    end

    def allow_cancel?
      return false if !completed? || canceled?

      shipment_state.nil? || %w{ready backorder pending canceled}.include?(shipment_state)
    end

    def all_inventory_units_returned?
      inventory_units.all?(&:returned?)
    end

    # Associates the specified user with the order.
    def associate_user!(user, override_email = true)
      self.user           = user
      self.email          = user.email if override_email
      # we need to check if user is of admin user class to avoid mismatch type error
      # in a scenario where we have separate classes for admin and regular users
      self.created_by   ||= user if user.is_a?(Spree.admin_user_class)
      self.bill_address ||= user.bill_address
      self.ship_address ||= user.ship_address

      changes = slice(*ASSOCIATED_USER_ATTRIBUTES)

      # immediately persist the changes we just made, but don't use save
      # since we might have an invalid address associated
      ActiveRecord::Base.connected_to(role: :writing) do
        self.class.unscoped.where(id: self).update_all(changes)
      end
    end

    def disassociate_user!
      nullified_attributes = ASSOCIATED_USER_ATTRIBUTES.index_with(nil)

      update!(nullified_attributes)
    end

    def quantity_of(variant, options = {})
      line_item = find_line_item_by_variant(variant, options)
      line_item ? line_item.quantity : 0
    end

    def find_line_item_by_variant(variant, options = {})
      line_items.detect do |line_item|
        line_item.variant_id == variant.id &&
          Spree::Dependencies.cart_compare_line_items_service.constantize.new.call(order: self, line_item: line_item, options: options).value
      end
    end

    # Creates new tax charges if there are any applicable rates. If prices already
    # include taxes then price adjustments are created instead.
    def create_tax_charge!
      Spree::TaxRate.adjust(self, line_items)
      Spree::TaxRate.adjust(self, shipments) if shipments.any?
    end

    def create_shipment_tax_charge!
      Spree::TaxRate.adjust(self, shipments) if shipments.any?
    end

    def update_line_item_prices!
      transaction do
        line_items.reload.each(&:update_price)
        save!
      end
    end

    def outstanding_balance
      if canceled?
        -1 * payment_total
      else
        total - (payment_total + reimbursement_paid_total)
      end
    end

    def reimbursement_paid_total
      reimbursements.sum(&:paid_amount)
    end

    def outstanding_balance?
      outstanding_balance != 0
    end

    def name
      if (address = bill_address || ship_address)
        address.full_name
      end
    end

    def full_name
      @full_name ||= if user.present? && user.name.present?
                       user.full_name
                     else
                       billing_address&.full_name || email
                     end
    end

    # Returns the payment method for the order
    #
    # @return [Spree::PaymentMethod] the payment method for the order
    def payment_method
      payments.valid.not_store_credits.first&.payment_method
    end

    # Returns the payment source for the order
    #
    # @return [Spree::PaymentSource] the payment source for the order
    def payment_source
      payments.valid.not_store_credits.first&.source
    end

    # Returns the backordered variants for the order
    #
    # @return [Array<Spree::Variant>] the backordered variants for the order
    def backordered_variants
      variants.
        where(track_inventory: true).
        joins(:stock_items, :product).
        where(Spree::StockItem.table_name => { count_on_hand: ..0, backorderable: true })
    end

    def can_ship?
      complete? || resumed? || awaiting_return? || returned?
    end

    def uneditable?
      complete? || canceled? || returned?
    end

    def credit_cards
      credit_card_ids = payments.from_credit_card.pluck(:source_id).uniq
      CreditCard.where(id: credit_card_ids)
    end

    def valid_credit_cards
      credit_card_ids = payments.from_credit_card.valid.pluck(:source_id).uniq
      CreditCard.where(id: credit_card_ids)
    end

    # Finalizes an in progress order after checkout is complete.
    # Called after transition to complete state when payments will have been processed
    def finalize!
      # lock all adjustments (coupon promotions, etc.)
      all_adjustments.each(&:close)

      # update payment and shipment(s) states, and save
      updater.update_payment_state
      shipments.each do |shipment|
        shipment.update!(self)
        shipment.finalize!
      end

      updater.update_shipment_state
      save!
      updater.run_hooks

      touch :completed_at

      deliver_order_confirmation_email unless confirmation_delivered?
      deliver_store_owner_order_notification_email if deliver_store_owner_order_notification_email?

      send_order_placed_webhook

      consider_risk
    end

    def fulfill!
      shipments.each { |shipment| shipment.update!(self) if shipment.persisted? }
      updater.update_shipment_state
      save!
    end

    # Helper methods for checkout steps
    def paid?
      payments.valid.completed.size == payments.valid.size && payments.valid.sum(:amount) >= total
    end

    def available_payment_methods(store = nil)
      Spree::Deprecation.warn('`Order#available_payment_methods` is deprecated and will be removed in Spree 6. Use `collect_frontend_payment_methods` instead.')
      if store.present?
        Spree::Deprecation.warn('The `store` parameter is deprecated and will be removed in Spree 5. Order is already associated with Store')
      end

      @available_payment_methods ||= collect_payment_methods(store)
    end

    def insufficient_stock_lines
      line_items.select(&:insufficient_stock?)
    end

    ##
    # Check to see if any line item variants are discontinued.
    # If so add error and restart checkout.
    def ensure_line_item_variants_are_not_discontinued
      if line_items.any? { |li| !li.variant || li.variant.discontinued? }
        restart_checkout_flow
        errors.add(:base, Spree.t(:discontinued_variants_present))
        false
      else
        true
      end
    end

    def ensure_line_items_are_in_stock
      if insufficient_stock_lines.present?
        restart_checkout_flow
        errors.add(:base, Spree.t(:insufficient_stock_lines_present))
        false
      else
        true
      end
    end

    def empty!
      raise Spree.t(:cannot_empty_completed_order) if completed?

      result = Spree::Dependencies.cart_empty_service.constantize.call(order: self)
      result.value
    end

    def use_all_coupon_codes
      Spree::CouponCodes::CouponCodesHandler.new(order: self).use_all_codes
    end

    def has_step?(step)
      checkout_steps.include?(step)
    end

    def state_changed(name)
      state = "#{name}_state"
      if persisted?
        old_state = send("#{state}_was")
        new_state = send(state)
        unless old_state == new_state
          log_state_changes(state_name: name, old_state: old_state, new_state: new_state)
        end
      end
    end

    def log_state_changes(state_name:, old_state:, new_state:)
      state_changes.create(
        previous_state: old_state,
        next_state: new_state,
        name: state_name,
        user_id: user_id
      )
    end

    def coupon_code=(code)
      @coupon_code = begin
        code.strip.downcase
      rescue StandardError
        nil
      end
    end

    def can_add_coupon?
      Spree::Promotion.order_activatable?(self)
    end

    def shipped?
      %w(partial shipped).include?(shipment_state)
    end

    def fully_shipped?
      shipments.shipped.size == shipments.size
    end

    def create_proposed_shipments
      all_adjustments.shipping.delete_all

      shipment_ids = shipments.map(&:id)
      StateChange.where(stateful_type: 'Spree::Shipment', stateful_id: shipment_ids).delete_all
      ShippingRate.where(shipment_id: shipment_ids).delete_all

      shipments.delete_all

      # Inventory Units which are not associated to any shipment (unshippable)
      # and are not returned or shipped should be deleted
      inventory_units.on_hand_or_backordered.delete_all

      self.shipments = Spree::Stock::Coordinator.new(self).shipments
    end

    # Returns the total weight of the inventory units in the order
    # This is used to calculate the shipping rates for the order
    #
    # @return [BigDecimal] the total weight of the inventory units in the order
    def total_weight
      @total_weight ||= line_items.joins(:variant).includes(:variant).map(&:item_weight).sum
    end

    # Returns line items that have no shipping rates
    #
    # @return [Array<Spree::LineItem>]
    def line_items_without_shipping_rates
      @line_items_without_shipping_rates ||= shipments.map do |shipment|
        shipment.manifest.map(&:line_item) if shipment.shipping_rates.blank?
      end.flatten.compact
    end

    # Checks if all line items cannot be shipped
    #
    # @returns Boolean
    def all_line_items_invalid?
      line_items_without_shipping_rates.size == line_items.count
    end

    def apply_free_shipping_promotions
      Spree::PromotionHandler::FreeShipping.new(self).activate
      shipments.each { |shipment| Spree::Adjustable::AdjustmentsUpdater.update(shipment) }
      create_shipment_tax_charge!
      update_with_updater!
    end

    # Applies user promotions when login after filling the cart
    def apply_unassigned_promotions
      ::Spree::PromotionHandler::Cart.new(self).activate
    end

    # Clean shipments and make order back to address state
    #
    # At some point the might need to force the order to transition from address
    # to delivery again so that proper updated shipments are created.
    # e.g. customer goes back from payment step and changes order items
    def ensure_updated_shipments
      if shipments.any? && !completed?
        shipments.destroy_all
        update_column(:shipment_total, 0)
        restart_checkout_flow
      end
    end

    def restart_checkout_flow
      update_columns(
        state: 'cart',
        updated_at: Time.current
      )
      next! unless line_items.empty?
    end

    def refresh_shipment_rates(shipping_method_filter = ShippingMethod::DISPLAY_ON_FRONT_END)
      shipments.map { |s| s.refresh_rates(shipping_method_filter) }
    end

    def shipping_eq_billing_address?
      bill_address == ship_address
    end

    def set_shipments_cost
      shipments.each(&:update_amounts)
      updater.update_shipment_total
      updater.update_adjustment_total
      persist_totals
    end

    def shipping_method
      # This query will select the first available shipping method from the shipments.
      # It will use subquery to first select the shipping method id from the shipments' selected_shipping_rate.
      Spree::ShippingMethod.
        where(id: shipments.with_selected_shipping_method.limit(1).pluck(:shipping_method_id)).
        limit(1).
        first
    end

    def is_risky?
      !payments.risky.empty?
    end

    def canceled_by(user, canceled_at = nil)
      canceled_at ||= Time.current

      transaction do
        update_columns(
          canceler_id: user.id,
          canceled_at: canceled_at
        )
        cancel!
      end
    end

    def approved_by(user)
      transaction do
        approve!
        update_columns(
          approver_id: user.id,
          approved_at: Time.current
        )
      end
    end

    def approved?
      !!approved_at
    end

    def can_approve?
      !approved?
    end

    def can_be_destroyed?
      Spree::Deprecation.warn('Spree::Order#can_be_destroyed? is deprecated and will be removed in the next major version. Use Spree::Order#can_be_deleted? instead.')
      can_be_deleted?
    end

    def can_be_deleted?
      !completed? && payments.completed.empty?
    end

    def consider_risk
      considered_risky! if is_risky? && !approved?
    end

    def considered_risky!
      update_column(:considered_risky, true)
    end

    def approve!
      update_column(:considered_risky, false)
    end

    def tax_total
      included_tax_total + additional_tax_total
    end

    def quantity
      line_items.sum(:quantity)
    end

    def has_non_reimbursement_related_refunds?
      refunds.non_reimbursement.exists? ||
        payments.offset_payment.exists? # how old versions of spree stored refunds
    end

    def collect_backend_payment_methods
      store.payment_methods.active.available_on_back_end.select { |pm| pm.available_for_order?(self) }
    end

    def collect_frontend_payment_methods
      store.payment_methods.active.available_on_front_end.select { |pm| pm.available_for_order?(self) }
    end

    # determines whether the inventory is fully discounted
    #
    # Returns
    # - true if inventory amount is the exact negative of inventory related adjustments
    # - false otherwise
    def fully_discounted?
      adjustment_total + line_items.map(&:final_amount).sum == 0.0
    end
    alias fully_discounted fully_discounted?

    def promo_code
      Spree::CouponCode.find_by(order: self, promotion: promotions).try(:code) || promotions.pluck(:code).compact.first
    end

    def valid_promotions
      order_promotions.where(promotion_id: valid_promotion_ids).uniq(&:promotion_id)
    end

    def valid_promotion_ids
      all_adjustments.eligible.nonzero.promotion.map { |a| a.source.promotion_id }.uniq
    end

    def valid_coupon_promotions
      promotions.
        where(id: valid_promotion_ids).
        coupons
    end

    # Returns item and whole order discount amount for Order
    # without Shipment disccounts (eg. Free Shipping)
    # @return [BigDecimal]
    def cart_promo_total
      all_adjustments.eligible.nonzero.promotion.
        where.not(adjustable_type: 'Spree::Shipment').
        sum(:amount)
    end

    def has_free_shipping?
      shipment_adjustments.
        joins(:promotion_action).
        where(spree_adjustments: { eligible: true, source_type: 'Spree::PromotionAction' },
              spree_promotion_actions: { type: 'Spree::Promotion::Actions::FreeShipping' }).exists?
    end

    def to_csv(_store = nil)
      metafields_for_csv ||= Spree::MetafieldDefinition.for_resource_type('Spree::Order').order(:namespace, :key).map do |mf_def|
        metafields.find { |mf| mf.metafield_definition_id == mf_def.id }&.csv_value
      end

      csv_lines = []
      all_line_items.each_with_index do |line_item, index|
        csv_lines << Spree::CSV::OrderLineItemPresenter.new(self, line_item, index, metafields_for_csv).call
      end
      csv_lines
    end

    def all_line_items
      line_items
    end

    def requires_ship_address?
      !digital?
    end

    private

    def link_by_email
      self.email = user.email if user
    end

    # Determine if email is required (we don't want validation errors before we hit the checkout)
    # we need to add delivery to the list for quick checkouts
    def require_email
      true unless new_record? || ['cart', 'address', 'delivery'].include?(state)
    end

    def ensure_line_items_present
      unless line_items.present?
        errors.add(:base, Spree.t(:there_are_no_items_for_this_order)) && (return false)
      end
    end

    def ensure_available_shipping_rates
      if shipments.empty? || line_items_without_shipping_rates.present?
        # After this point, order redirects back to 'address' state and asks user to pick a proper address
        # Therefore, shipments are not necessary at this point.
        shipments.destroy_all

        if line_items_without_shipping_rates.present?
          errors.add(:base, Spree.t(:products_cannot_be_shipped, product_names: line_items_without_shipping_rates.map(&:name).to_sentence))
        else
          errors.add(:base, Spree.t(:items_cannot_be_shipped))
        end

        return false
      end
    end

    def after_cancel
      shipments.each(&:cancel!)

      # payments fully covered by gift card won't be refunded
      # we want to only void the payment
      if gift_card.present? && covered_by_store_credit?
        payments.completed.store_credits.each(&:void!)
      else
        payments.completed.each(&:cancel!)
        payments.store_credits.pending.each(&:void!)
      end

      send_cancel_email
      update_with_updater!
      send_order_canceled_webhook
    end

    def after_resume
      shipments.each(&:resume!)
      consider_risk
      send_order_resumed_webhook
    end

    def use_billing?
      use_billing.in?([true, 'true', '1'])
    end

    def use_shipping?
      use_shipping.in?([true, 'true', '1'])
    end

    def ensure_currency_presence
      self.currency ||= store&.default_currency
    end

    def collect_payment_methods(store = nil)
      Spree::Deprecation.warn('`Order#collect_payment_methods` is deprecated and will be removed in Spree 6. Use `collect_frontend_payment_methods` instead.')
      if store.present?
        Spree::Deprecation.warn('The `store` parameter is deprecated and will be removed in Spree 5. Order is already associated with Store')
      end
      store ||= self.store

      store.payment_methods.available_on_front_end.select { |pm| pm.available_for_order?(self) }
    end

    def credit_card_nil_payment?(attributes)
      payments.store_credits.present? && attributes[:amount].to_f.zero?
    end

    def recalculate_store_credit_payment
      updater.update_adjustment_total if using_store_credit?

      if gift_card.present?
        recalculate_gift_card
      elsif using_store_credit?
        Spree::Dependencies.checkout_add_store_credit_service.constantize.call(order: self)
      end
    end
  end
end
