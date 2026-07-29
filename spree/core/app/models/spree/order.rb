require_dependency 'spree/order/checkout'
require_dependency 'spree/order/currency_updater'
require_dependency 'spree/order/digital'
require_dependency 'spree/order/payments'
require_dependency 'spree/order/store_credit'
require_dependency 'spree/order/gift_card'

module Spree
  class Order < Spree.base_class
    has_prefix_id :or  # Stripe: or_

    # Legacy free-text `channel` column was replaced by the `channel_id` FK
    # (see 6.0-order-routing.md). The string column stays in the DB so the
    # 5.4-to-5.5 backfill rake can read it; AR ignores it everywhere else.
    self.ignored_columns += ['channel']

    PAYMENT_STATES = %w(balance_due credit_owed failed paid void)
    FULFILLMENT_STATUSES = %w(backorder canceled partial pending ready fulfilled shipped)
    # @deprecated legacy name — remove in 6.1 together with the 'shipped' value
    SHIPMENT_STATES = FULFILLMENT_STATUSES
    # @deprecated legacy machine vocabulary — line-item removability is
    #   completion-based since 6.0; removed in 6.1.
    LINE_ITEM_REMOVABLE_STATES = %w(cart address delivery payment confirm resumed)

    extend Spree::DisplayMoney

    include Spree::Order::Checkout
    include Spree::Order::CurrencyUpdater
    include Spree::Order::Digital
    include Spree::Order::Payments
    include Spree::Order::StoreCredit
    include Spree::Order::AddressBook
    include Spree::Order::Webhooks
    include Spree::Core::NumberGenerator.new(prefix: 'R')
    include Spree::Order::GiftCard

    include Spree::NumberIdentifier
    include Spree::SingleStoreResource

    publishes_lifecycle_events
    include Spree::MemoizedData
    include Spree::Metafields
    include Spree::Metadata
    include Spree::Searchable
    if defined?(Spree::Security::Orders)
      include Spree::Security::Orders
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end

    has_secure_token :token, length: 35
    has_rich_text :internal_note

    MEMOIZED_METHODS = %w(tax_zone)

    money_methods :outstanding_balance, :item_total,           :adjustment_total,
                  :included_tax_total,  :additional_tax_total, :tax_total,
                  :delivery_total,      :discount_total,       :total,
                  :cart_promo_total,    :pre_tax_item_amount,  :pre_tax_total,
                  :payment_total,       :amount_due

    alias display_ship_total display_delivery_total
    alias_attribute :ship_total, :delivery_total
    def amount_due
      [outstanding_balance - total_applied_store_credit, 0].max
    end

    # Transient warnings populated by remove_out_of_stock_items! and ensure_available_shipping_rates
    attribute :warnings, default: -> { [] }

    # Removes out-of-stock/discontinued items and populates warnings.
    # Returns self (reloaded if items were removed) with warnings set.
    # Captured before the call because removing items reloads the order, which
    # would drop warnings already recorded upstream.
    def remove_out_of_stock_items!
      existing_warnings = warnings
      result = Spree::Carts::RemoveOutOfStockItems.call(order: self)
      return self unless result.success?

      order, _messages, new_warnings = result.value
      order.warnings = existing_warnings | (new_warnings || [])
      order
    end

    # Standardized column names (renamed in 6.0); legacy readers stay as
    # aliases one release.
    alias_attribute :promo_total, :discount_total
    alias display_promo_total display_discount_total
    alias_attribute :customer_note, :special_instructions
    alias_attribute :item_count, :total_quantity

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

    # lock_version (renamed from state_lock_version) drives the API's manual
    # optimistic concurrency (compare client-sent version, 409 on mismatch) —
    # Rails auto-locking must not raise on internal saves.
    self.lock_optimistically = false

    self.whitelisted_ransackable_associations = %w[fulfillments shipments user created_by approver canceler promotions bill_address ship_address line_items store channel tags]
    self.whitelisted_ransackable_attributes = %w[
      completed_at email number status payment_status payment_state fulfillment_status shipment_state delivery_total
      total item_total total_quantity considered_risky channel_id currency coupon_code
    ]
    self.whitelisted_ransackable_scopes = %w[complete incomplete refunded partially_refunded search multi_search]

    attr_accessor :temporary_address

    # Set to false on admin-initiated flows to suppress customer-facing emails.
    attr_accessor :notify_customer

    attribute :state_machine_resumed, :boolean

    STATUSES = %w[draft placed canceled].freeze

    attribute :status, :string, default: 'draft'
    validates :status, inclusion: { in: STATUSES }

    scope :drafts,         -> { where(status: 'draft') }
    scope :placed_orders,  -> { where(status: 'placed') }
    scope :canceled_orders, -> { where(status: 'canceled') }

    acts_as_taggable_on :tags
    acts_as_taggable_tenant :store_id

    def tags=(tags)
      self.tag_list = tags
    end

    ASSOCIATED_USER_ATTRIBUTES = [:user_id, :email, :bill_address_id, :ship_address_id]

    # 6.0 forward-compat: User→Customer rename. Column stays user_id in 5.x.
    alias_attribute :customer_id, :user_id

    belongs_to :user, class_name: "::#{Spree.user_class}", optional: true, autosave: true
    # The cart this order was completed from (unique — the completion
    # idempotency key). Backoffice draft orders have no cart.
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :order
    belongs_to :created_by, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :approver, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :canceler, class_name: "::#{Spree.admin_user_class}", optional: true

    belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address',
                              optional: true, dependent: :destroy
    alias_method :billing_address, :bill_address
    alias_method :billing_address=, :bill_address=
    alias_attribute :billing_address_id, :bill_address_id

    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address',
                              optional: true, dependent: :destroy
    alias_method :shipping_address, :ship_address
    alias_method :shipping_address=, :ship_address=
    alias_attribute :shipping_address_id, :ship_address_id

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :market, class_name: 'Spree::Market'
    belongs_to :channel, class_name: 'Spree::Channel'
    belongs_to :preferred_stock_location, class_name: 'Spree::StockLocation', optional: true

    with_options dependent: :destroy do
      has_many :state_changes, as: :stateful, class_name: 'Spree::StateChange'
      has_many :line_items, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::LineItem'
      has_many :payments, class_name: 'Spree::Payment'
      has_many :payment_sessions, inverse_of: :order, class_name: 'Spree::PaymentSession'
      has_many :return_authorizations, inverse_of: :order, class_name: 'Spree::ReturnAuthorization'
      has_many :cancellations, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::OrderCancellation'
      has_many :approvals, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::OrderApproval'
    end
    has_many :reimbursements, inverse_of: :order, class_name: 'Spree::Reimbursement'
    has_many :customer_returns, class_name: 'Spree::CustomerReturn', through: :return_authorizations
    has_many :fulfillment_items, inverse_of: :order, class_name: 'Spree::FulfillmentItem'
    has_many :inventory_units, class_name: 'Spree::FulfillmentItem', inverse_of: :order, deprecated: true
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :order, dependent: :destroy
    has_many :return_items, through: :fulfillment_items, class_name: 'Spree::ReturnItem'
    has_many :variants, through: :line_items
    has_many :products, through: :variants
    has_many :refunds, through: :payments

    # Typed adjustment rows owned by this order (line-, fulfillment- and
    # order-level). See docs/plans/6.0-split-adjustments.md.
    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :order
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :order
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :order

    has_many :line_item_tax_lines, through: :line_items, source: :tax_lines
    has_many :line_item_discounts, through: :line_items, source: :discounts

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :promotions, through: :order_promotions, class_name: 'Spree::Promotion'

    has_many :fulfillments, class_name: 'Spree::Fulfillment', dependent: :destroy, inverse_of: :order do
      def states
        pluck(:status).uniq
      end
    end
    has_many :fulfillment_tax_lines, through: :fulfillments, source: :tax_lines
    has_many :fulfillment_discounts, through: :fulfillments, source: :discounts

    alias items line_items
    # Legacy names — removed in 6.1 (real names: fulfillments, delivery_total,
    # fulfillment_status since 6.0)
    has_many :shipments, class_name: 'Spree::Fulfillment', inverse_of: :order, deprecated: true
    alias_attribute :shipment_total, :delivery_total
    alias display_shipment_total display_delivery_total
    alias_attribute :shipment_state, :fulfillment_status
    # Deprecated alias — the column is payment_status since 6.0; remove in 6.1.
    alias_attribute :payment_state, :payment_status

    delegate :has_markets?, to: :store, prefix: true

    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :bill_address
    accepts_nested_attributes_for :ship_address
    alias shipping_address_attributes= ship_address_attributes=
    alias billing_address_attributes= bill_address_attributes=
    accepts_nested_attributes_for :payments, reject_if: :credit_card_nil_payment?
    accepts_nested_attributes_for :fulfillments
    # @deprecated legacy writer — removed in 6.1
    alias shipments_attributes= fulfillments_attributes=

    # Needs to happen before save_permalink is called
    before_validation :ensure_market_presence
    before_validation :ensure_channel_presence
    before_validation :ensure_currency_presence
    before_validation :ensure_locale_presence
    before_validation :resolve_market_from_currency, if: -> { persisted? && currency_changed? && !skip_market_resolution }

    before_validation :clone_billing_address, if: :use_billing?
    before_validation :clone_shipping_address, if: :use_shipping?
    attr_accessor :use_billing, :use_shipping, :skip_market_resolution

    before_create :link_by_email
    before_update :ensure_updated_shipments, :homogenize_line_item_currencies, if: :currency_changed?

    with_options presence: true do
      # we want to have this case_sentive: true as changing it to false causes all SQL to use LOWER(slug)
      # which is very costly and slow on large set of records
      validates :email, length: { maximum: 254, allow_blank: true }, email: { allow_blank: true }, if: :require_email
      validates :total_quantity, numericality: { greater_than_or_equal_to: 0, less_than: 2**31, only_integer: true, allow_blank: true }
      validates :store
      validates :currency
      validates :locale
    end
    validates :payment_status,       inclusion:    { in: PAYMENT_STATES, allow_blank: true }
    validates :fulfillment_status,   inclusion:    { in: FULFILLMENT_STATUSES, allow_blank: true }
    validates :item_total,           POSITIVE_MONEY_VALIDATION
    validates :adjustment_total,     MONEY_VALIDATION
    validates :included_tax_total,   POSITIVE_MONEY_VALIDATION
    validates :additional_tax_total, POSITIVE_MONEY_VALIDATION
    validates :payment_total,        MONEY_VALIDATION
    validates :delivery_total,       MONEY_VALIDATION
    validates :discount_total,       NEGATIVE_MONEY_VALIDATION
    validates :total,                MONEY_VALIDATION
    validate :currency_must_be_supported_by_store
    validate :locale_must_be_supported_by_store

    delegate :update_totals, :persist_totals, to: :updater
    delegate :merge!, to: :merger
    delegate :firstname, :lastname, to: :bill_address, prefix: true, allow_nil: true

    class_attribute :update_hooks
    self.update_hooks = Set.new

    scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
    scope :completed_between, ->(start_date, end_date) { where(completed_at: start_date..end_date) }
    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }
    scope :canceled, -> { where(status: 'canceled') }
    scope :not_canceled, -> { where.not(status: 'canceled') }
    scope :ready_to_ship, -> { where(fulfillment_status: %w[ready pending]) }
    scope :partially_shipped, -> { where(fulfillment_status: %w[partial]) }
    scope :not_shipped, -> { where(fulfillment_status: %w[ready pending partial]) }
    scope :shipped, -> { where(fulfillment_status: %w[fulfilled shipped]) }
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

    def self.search(query)
      sanitized_query = sanitize_query_for_search(query)
      return none if query.blank?

      query_pattern = "%#{sanitized_query}%"

      conditions = []
      conditions << arel_table[:number].lower.matches(query_pattern)

      conditions << search_condition(Spree::Address, :firstname, sanitized_query)
      conditions << search_condition(Spree::Address, :lastname, sanitized_query)

      full_name = NameOfPerson::PersonName.full(sanitized_query)

      if full_name.first.present? && full_name.last.present?
        conditions << search_condition(Spree::Address, :firstname, full_name.first)
        conditions << search_condition(Spree::Address, :lastname, full_name.last)
      end

      left_joins(:bill_address).where(arel_table[:email].lower.eq(query.downcase)).or(where(conditions.reduce(:or)))
    end

    # Backward compatibility alias — remove in Spree 6.0
    def self.multi_search(query) = search(query)

    # Find an order by prefixed ID first, falling back to number, then integer id for backwards compatibility
    # @param param [String] the prefixed ID, number, or integer id to search for
    # @return [Spree::Order, nil] the found order or nil
    def self.find_by_param(param)
      return nil if param.blank?

      # Try prefixed ID first (new format)
      if param.to_s.include?('_')
        decoded = decode_prefixed_id(param)
        order = find_by(id: decoded) if decoded
        return order if order
      end

      # Try number (legacy format)
      order = find_by(number: param)
      return order if order

      # Fall back to id (numeric legacy format) - only if param looks like an integer
      find_by(id: param) if param.to_s.match?(/\A\d+\z/)
    end

    # Find an order by prefixed ID first, falling back to number, then integer id for backwards compatibility
    # Raises ActiveRecord::RecordNotFound if not found
    # @param param [String] the prefixed ID, number, or integer id to search for
    # @return [Spree::Order] the found order
    # @raise [ActiveRecord::RecordNotFound] if order not found
    def self.find_by_param!(param)
      find_by_param(param) || raise(ActiveRecord::RecordNotFound.new("Couldn't find Order with param=#{param}"))
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

    # Sum of the eligible promotion adjustments applied to the order itself
    # (whole-order discounts created by Promotion::Actions::CreateAdjustment,
    # distributed proportionally across line items), as opposed to promotions
    # applied to individual line items or fulfillments. Zero or negative.
    #
    # @return [BigDecimal]
    def order_level_promo_total
      discounts.promotion.where(promotion_action_id: promotion_actions_of_scope(:order)).sum(:amount)
    end

    # Sum of all line item and shipment pre-tax
    def pre_tax_total
      pre_tax_item_amount + fulfillments.sum(:pre_tax_amount)
    end

    # Promotion actions of the given discount scope, covering both the 6.0
    # class names and the legacy STI names still present in the type column
    # until the 6.1 data migration.
    def promotion_actions_of_scope(scope)
      Spree::PromotionAction.where(type: Spree::PromotionAction.types_for_discount_scope(scope))
    end

    # Returns the subtotal used for analytics integrations
    # It's a sum of the item total and the promo total
    # @return [Float]
    def analytics_subtotal
      (item_total + line_items.sum(:promo_total)).to_f
    end

    def shipping_discount
      discounts.for_fulfillments.sum(:amount) * -1
    end

    def completed?
      completed_at.present?
    end

    # Orders are never mid-checkout since the cart flip — only a draft mid
    # completion (or an admin draft) is still mutable.
    def in_checkout?
      draft? && !completed? && !canceled? && !cart?
    end

    def draft?
      status == 'draft'
    end

    def placed?
      status == 'placed'
    end

    def canceled?
      status == 'canceled'
    end

    alias complete? completed?

    # @deprecated machine vocabulary — data-derived bridge for the 6.0
    #   transition, removed in 6.1. An order is "cart-like" while a draft
    #   with no checkout data.
    def cart?
      draft? && !completed? && email.blank? && ship_address_id.blank?
    end

    # @deprecated machine vocabulary — resumption is tracked by the transient
    #   flag only; removed in 6.1.
    def resumed?
      !!state_machine_resumed
    end

    # Derived, not stored (Decision 8): some but not all fulfillments canceled.
    def partially_canceled?
      !canceled? && fulfillments.canceled.any? && fulfillments.where.not(status: 'canceled').any?
    end

    # Checks if the order is fully refunded
    # @return [Boolean]
    def order_refunded?
      return false if total_quantity.zero?
      return false if refunds_total.zero?

      payment_state.in?(%w[void failed]) || refunds_total == total_minus_store_credits - additional_tax_total.abs
    end

    def refunds_total
      refunds.loaded? ? refunds.sum(&:amount) : refunds.sum(:amount)
    end

    # Checks if the order is partially refunded
    # @return [Boolean]
    def partially_refunded?
      return false if total_quantity.zero?
      return false if payment_state.in?(%w[void failed]) || refunds.empty?

      refunds_total < total_minus_store_credits - additional_tax_total.abs
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
    # Computed from data only — whether the confirm/review step exists never
    # falls back to a machine state (the #4117 hack died with the machine).
    def confirmation_required?
      Spree::Config[:always_include_confirm_step] ||
        payments.valid.map(&:payment_method).compact.any?(&:confirmation_required?)
    end

    def email_required?
      require_email
    end

    def backordered?
      fulfillments.any?(&:backordered?)
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
      payment_required? && fulfillments.count <= 1 && (digital? || !some_digital? || !delivery_required?)
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
      @updater ||= Spree.order_updater.new(self)
    end

    def update_with_updater!
      updater.update
    end

    def merger
      @merger ||= Spree::OrderMerger.new(self)
    end

    def ensure_store_presence
      Spree::Deprecation.warn('Spree::Order#ensure_store_presence is deprecated and will be removed in Spree 6.0. ensure_store instead.')
      ensure_store
    end

    def ensure_market_presence
      self.market ||= Spree::Current.market || store&.default_market
    end

    def ensure_channel_presence
      return if channel_id.present?

      self.channel = store&.default_channel
    end

    # @return [Boolean] true when this order has no registered user and its
    #   channel forbids guest checkout (see Spree::Channel::Gating). Enforced by
    #   the checkout completion service and the v3 Store API so every completion
    #   path (controller, payment webhook) is covered.
    #
    #   A +prices_hidden+ channel also disallows guest completion regardless of
    #   the +guest_checkout+ flag — prices are withheld from guests, and a buyer
    #   who cannot see prices cannot meaningfully place an order. This dissolves
    #   the otherwise contradictory "prices hidden but guests may buy" config.
    def guest_checkout_disallowed?
      return false if user_id.present?
      return false if channel.blank?
      return true if channel.storefront_prices_hidden?

      !channel.resolved_guest_checkout
    end

    def allow_cancel?
      return false if !completed? || canceled?

      fulfillment_status.nil? || %w{ready backorder pending canceled}.include?(fulfillment_status)
    end
    alias can_cancel? allow_cancel?

    def all_inventory_units_returned?
      inventory_units.all?(&:returned?)
    end

    # Associates the specified user with the order.
    # Delegates to {Spree::Carts::Associate} service.
    #
    # @param user [Spree.user_class] the user to associate with the order
    # @param override_email [Boolean] whether to override the order email with the user's email
    # @return [Spree::ServiceModule::Result]
    def associate_user!(user, override_email = true)
      Spree.cart_associate_service.call(guest_order: self, user: user, override_email: override_email)
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
          Spree.cart_compare_line_items_service.new.call(order: self, line_item: line_item, options: options).value
      end
    end

    # Re-estimates tax through the configured provider (writes TaxLine rows
    # with replace-all semantics).
    def create_tax_charge!
      Spree.tax_provider.estimate(self)
    end

    def create_shipment_tax_charge!
      Spree.tax_provider.estimate(self, fulfillments.to_a) if fulfillments.any?
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
      placed?
    end

    def uneditable?
      completed? || canceled?
    end

    # Finalizes an in progress order after checkout is complete.
    # Called after transition to complete state when payments will have been processed
    def finalize!
      # Typed adjustment rows are frozen by the order-level recalculation
      # freeze (OrderUpdater#recalculate_adjustments) once completed — no
      # per-row locking needed.

      # update payment and shipment(s) states, and save
      updater.update_payment_state
      fulfillments.each do |shipment|
        shipment.update!(self)
        shipment.finalize!
      end

      updater.update_fulfillment_status
      self.status = 'placed'
      save!
      updater.run_hooks

      touch :completed_at

      # Completion side effects previously wired as machine transition
      # callbacks — each guards its own idempotency.
      use_all_coupon_codes
      redeem_gift_card
      subscribe_to_newsletter
      create_user_record

      auto_fulfill_provider_fulfillments

      send_order_placed_webhook

      consider_risk

      publish_order_completed_event
    end

    def fulfill!
      fulfillments.each { |shipment| shipment.update!(self) if shipment.persisted? }
      updater.update_fulfillment_status
      save!
    end

    # Helper methods for checkout steps
    def paid?
      payments.valid.completed.size == payments.valid.size && payments.valid.sum(:amount) >= total
    end

    def payment_methods
      @payment_methods ||= store.payment_methods.active.available_on_front_end.select { |pm| pm.available_for_order?(self) }
    end

    def available_payment_methods(store = nil)
      Spree::Deprecation.warn('`Order#available_payment_methods` is deprecated and will be removed in Spree 5.5. Use `collect_frontend_payment_methods` instead.')

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
        errors.add(:base, Spree.t(:discontinued_variants_present))
        false
      else
        true
      end
    end

    def ensure_line_items_are_in_stock
      if insufficient_stock_lines.present?
        errors.add(:base, Spree.t(:insufficient_stock_lines_present))
        false
      else
        true
      end
    end

    def empty!
      raise Spree.t(:cannot_empty_completed_order) if completed?

      result = Spree.cart_empty_service.call(order: self)
      result.value
    end

    def use_all_coupon_codes
      Spree::CouponCodes::CouponCodesHandler.new(order: self).use_all_codes
    end

    def has_step?(step)
      checkout_steps.include?(step)
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
      normalized = begin
        code.strip.downcase
      rescue StandardError
        nil
      end
      super(normalized)
    end

    def can_add_coupon?
      Spree::Promotion.order_activatable?(self)
    end

    def shipped?
      %w(partial shipped fulfilled).include?(fulfillment_status)
    end

    # True when every fulfillment reached the fulfilled status — the signal
    # order.fulfilled publishes on.
    def fully_fulfilled?
      fulfillments.fulfilled.size == fulfillments.size
    end

    # @deprecated Use {#fully_fulfilled?}; removed in 6.1.
    def fully_shipped?
      Spree::Deprecation.warn('Spree::Order#fully_shipped? is deprecated and will be removed in Spree 6.1. Use #fully_fulfilled? instead.')
      fully_fulfilled?
    end

    def create_proposed_shipments
      discounts.for_fulfillments.delete_all
      tax_lines.for_fulfillments.delete_all
      fees.for_fulfillments.delete_all

      shipment_ids = fulfillments.map(&:id)
      StateChange.where(stateful_type: %w[Spree::Shipment Spree::Fulfillment], stateful_id: shipment_ids).delete_all
      DeliveryRate.where(fulfillment_id: shipment_ids).delete_all

      fulfillments.delete_all

      # Inventory Units which are not associated to any shipment (unshippable)
      # and are not returned or shipped should be deleted
      fulfillment_items.on_hand_or_backordered.delete_all

      self.fulfillments = order_routing_strategy.for_allocation.map do |package|
        package.to_shipment.tap { |s| s.address_id = ship_address_id }
      end
    end

    # Resolves the routing strategy from the channel override first, then the
    # store default. Only a registered Spree::OrderRouting::Strategy::Base
    # subclass is used; any other value (an unregistered/typo'd class, or a
    # strategy that was unregistered after being persisted) is logged and
    # skipped rather than raised, falling back to the default Rules strategy so
    # a misconfiguration can't take down cart display or checkout.
    #
    # @return [Spree::OrderRouting::Strategy::Base]
    def order_routing_strategy
      klass = valid_order_routing_strategy_class(channel&.preferred_order_routing_strategy) ||
              valid_order_routing_strategy_class(store.preferred_order_routing_strategy) ||
              Spree::OrderRouting::Strategy::Rules

      klass.new(order: self)
    end

    # Cascade for the `preferred_location` rule kind. Channel and B2B sources
    # are layered in by their respective plans.
    #
    # @return [Integer, nil]
    def inferred_preferred_stock_location_id
      preferred_stock_location_id.presence ||
        created_by&.try(:preferred_stock_location_id)
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
      @line_items_without_shipping_rates ||= fulfillments.map do |shipment|
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
      update_with_updater!
    end

    # Applies user promotions when login after filling the cart
    def apply_unassigned_promotions
      ::Spree::PromotionHandler::Cart.new(self).activate
    end

    # Drops stale fulfillments so they are rebuilt from current items.
    def ensure_updated_shipments
      if fulfillments.any? && !completed?
        fulfillments.destroy_all
        update_column(:delivery_total, 0)

        # Manually publish update event since update_column bypasses callbacks
        publish_event('order.updated')
      end
    end

    def refresh_shipment_rates(shipping_method_filter = DeliveryMethod::DISPLAY_ON_FRONT_END)
      fulfillments.map { |s| s.refresh_rates(shipping_method_filter) }
    end

    def shipping_eq_billing_address?
      bill_address == ship_address
    end

    def set_shipments_cost
      fulfillments.each(&:update_amounts)
      updater.update_delivery_total
      updater.update_adjustment_total
      persist_totals
    end

    def shipping_method
      # This query will select the first available shipping method from the shipments.
      # It will use subquery to first select the shipping method id from the shipments' selected_shipping_rate.
      Spree::DeliveryMethod.
        where(id: fulfillments.with_selected_delivery_method.limit(1).pluck(:delivery_method_id)).
        limit(1).
        first
    end

    def is_risky?
      !payments.risky.empty?
    end

    # Cancels the order and records the canceler.
    # Delegates to {Spree::Orders::Cancel} service.
    #
    # @param user [Spree.user_class, nil] the user who canceled the order
    # @param canceled_at [Time, nil] the time of cancellation (defaults to current time)
    # @return [Spree::ServiceModule::Result]
    def canceled_by(user, canceled_at = nil)
      Spree.order_cancel_service.call(order: self, canceler: user, canceled_at: canceled_at)
    end

    # Machine-free lifecycle: cancel/resume flip +status+ and run the same
    # side effects the machine transitions ran.
    def cancel
      return false unless allow_cancel?

      update_column(:canceled_at, Time.current) if canceled_at.blank?
      after_cancel
      true
    end

    def cancel!
      cancel || raise(ActiveRecord::RecordInvalid.new(self))
    end

    def resume
      return false unless canceled?

      self.state_machine_resumed = true
      after_resume
      true
    end

    def resume!
      resume || raise(ActiveRecord::RecordInvalid.new(self))
    end

    # Approves the order and records the approver.
    # Delegates to {Spree::Orders::Approve} service.
    #
    # @param user [Spree.user_class, nil] the user who approved the order
    # @return [Spree::ServiceModule::Result]
    def approved_by(user = nil)
      Spree.order_approve_service.call(order: self, approver: user)
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

      # Manually publish update event since update_column bypasses callbacks
      publish_event('order.updated')
    end

    # Approves the order without recording an approver.
    # Delegates to {Spree::Orders::Approve} service.
    #
    # @return [Spree::ServiceModule::Result]
    def approve!
      Spree.order_approve_service.call(order: self)
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

    # Returns the valid promotions for the order
    # @return [Array<Spree::OrderPromotion>]
    def valid_promotions
      order_promotions.includes(:promotion).where(promotion_id: valid_promotion_ids).uniq(&:promotion_id)
    end

    # Returns the IDs of the valid promotions for the order
    # @return [Array<Integer>]
    def valid_promotion_ids
      discounts.promotion.nonzero.where.not(promotion_id: nil).distinct.pluck(:promotion_id)
    end

    # Returns the valid coupon promotions for the order
    # @return [Array<Spree::Promotion>]
    def valid_coupon_promotions
      promotions.
        where(id: valid_promotion_ids).
        coupons
    end

    # Returns item and whole order discount amount for Order
    # without fulfillment discounts (eg. Free Shipping)
    # @return [BigDecimal]
    def cart_promo_total
      discounts.promotion.nonzero.for_line_items.sum(:amount)
    end

    def has_free_shipping?
      discounts.promotion.for_fulfillments.exists?
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

    def valid_order_routing_strategy_class(klass_name)
      return if klass_name.blank?

      klass = Spree.order_routing.strategies.find { |strategy| strategy.to_s == klass_name.to_s }
      return klass if klass

      Rails.logger.warn(
        "[Spree] Ignoring unregistered order routing strategy #{klass_name.inspect} " \
        "for order #{number.inspect}; falling back to the default strategy."
      )
      nil
    end

    def link_by_email
      self.email = user.email if user
    end

    # Determine if email is required (we don't want validation errors before we hit the checkout)
    # we need to add delivery to the list for quick checkouts
    def require_email
      !new_record? && (completed? || placed?)
    end

    def ensure_line_items_present
      unless line_items.present?
        errors.add(:base, Spree.t(:there_are_no_items_for_this_order)) && (return false)
      end
    end

    def ensure_available_shipping_rates
      if fulfillments.empty? || line_items_without_shipping_rates.present?
        # After this point, order redirects back to 'address' state and asks user to pick a proper address
        # Therefore, shipments are not necessary at this point.
        fulfillments.destroy_all

        if line_items_without_shipping_rates.present?
          errors.add(:base, Spree.t(:products_cannot_be_shipped, product_names: line_items_without_shipping_rates.map(&:name).to_sentence))
          self.warnings |= line_items_without_shipping_rates.map do |line_item|
            {
              code: 'delivery_unavailable',
              message: Spree.t('cart_line_item.delivery_unavailable', li_name: line_item.name),
              line_item_id: line_item.prefixed_id,
              variant_id: line_item.variant&.prefixed_id
            }
          end
        else
          errors.add(:base, Spree.t(:items_cannot_be_shipped))
          self.warnings |= [{ code: 'delivery_unavailable', message: Spree.t(:items_cannot_be_shipped) }]
        end

        false
      end
    end

    def after_cancel
      update_column(:status, 'canceled')

      fulfillments.each(&:cancel!)

      # payments fully covered by gift card won't be refunded
      # we want to only void the payment
      if gift_card.present? && covered_by_store_credit?
        payments.completed.store_credits.each(&:void!)
      else
        payments.completed.each(&:cancel!)
        payments.incomplete.not_store_credits.each(&:void_transaction!)
        payments.store_credits.pending.each(&:void!)
      end

      update_with_updater!
      send_order_canceled_webhook
    end

    def after_resume
      update_column(:status, 'placed')

      fulfillments.each(&:resume!)
      consider_risk
      send_order_resumed_webhook
      publish_order_resumed_event
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

    # Sets the locale from Spree::Current.locale when not already set.
    # Called as a before_validation callback, mirroring ensure_currency_presence.
    def ensure_locale_presence
      self.locale ||= Spree::Current.locale
    end

    def currency_must_be_supported_by_store
      return if currency.blank? || store.blank?

      supported_codes = store.supported_currencies_list.map(&:iso_code)
      unless supported_codes.include?(currency)
        errors.add(:currency, Spree.t(:currency_not_supported_by_store))
      end
    end

    # Validates that the order's locale is within the store's supported locales.
    # Mirrors currency_must_be_supported_by_store.
    def locale_must_be_supported_by_store
      return if locale.blank? || store.blank?

      unless store.supported_locales_list.include?(locale)
        errors.add(:locale, Spree.t(:locale_not_supported_by_store))
      end
    end

    # When currency changes, auto-resolve the matching market.
    # Only applies when the store has markets configured.
    def resolve_market_from_currency
      return unless store_has_markets?
      return if market&.currency == currency

      resolved = store.markets.find_by(currency: currency)
      self.market = resolved if resolved
    end

    def collect_payment_methods
      Spree::Deprecation.warn('`Order#collect_payment_methods` is deprecated and will be removed in Spree 5.5. Use `collect_frontend_payment_methods` instead.')

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
        Spree.checkout_add_store_credit_service.call(order: self)
      end
    end

    def publish_order_completed_event
      publish_event('order.completed', event_payload.merge(notify_customer: notify_customer))
    end

    def publish_order_resumed_event
      publish_event('order.resumed')
    end
  end
end
