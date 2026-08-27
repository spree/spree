
module Spree
  class Order < Spree.base_class
    has_prefix_id :or  # Stripe: or_

    # Legacy free-text `channel` column was replaced by the `channel_id` FK
    # (see 6.0-order-routing.md). The string column stays in the DB so the
    # 5.4-to-5.5 backfill rake can read it; AR ignores it everywhere else.
    self.ignored_columns += ['channel']

    # What Orders::UpdateStatuses derives — the only writer of the column.
    PAYMENT_STATUSES = %w(none authorized partially_paid paid partially_refunded refunded overcharged voided).freeze
    # @deprecated legacy machine vocabulary; rows carrying it stay valid until
    #   the status migration rewrites them. Removed in 6.1.
    PAYMENT_STATES = %w(balance_due credit_owed failed paid void)
    FULFILLMENT_STATUSES = %w(backorder canceled partial unfulfilled fulfilled delivered pending ready shipped)
    # @deprecated legacy name — remove in 6.1 together with the 'shipped' value
    SHIPMENT_STATES = FULFILLMENT_STATUSES
    # @deprecated legacy machine vocabulary — line-item removability is
    #   completion-based since 6.0; removed in 6.1.
    LINE_ITEM_REMOVABLE_STATES = %w(cart address delivery payment confirm resumed)

    extend Spree::DisplayMoney

    include Spree::SingleStoreResource
    include Spree::SanitizableRichText
    include Spree::Purchase::Channel
    include Spree::Purchase::Company
    include Spree::Purchase::Market
    include Spree::Purchase::Currency
    include Spree::Purchase::Locale
    include Spree::Purchase::DigitalItems
    include Spree::Purchase::Taxation
    include Spree::Purchase::StoreCredits
    include Spree::Purchase::GiftCards
    include Spree::Purchase::LineItemCurrencies
    include Spree::Purchase::PaymentProcessing
    include Spree::Purchase::Addresses
    include Spree::Purchase::Validations
    include Spree::Purchase::Totals
    include Spree::Purchase::Lifecycle
    has_spree_number prefix: 'R'

    include Spree::NumberIdentifier

    publishes_lifecycle_events
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::HasExternalReferences
    include Spree::Searchable
    if defined?(Spree::Security::Orders)
      include Spree::Security::Orders
    end

    has_secure_token :token, length: 35

    has_spree_rich_text :internal_note

    money_methods :outstanding_balance, :item_total,           :adjustment_total,
                  :included_tax_total,  :additional_tax_total, :tax_total,
                  :delivery_total,      :discount_total,       :total,
                  :cart_promo_total,    :pre_tax_item_amount,  :pre_tax_total,
                  :payment_total,       :amount_due,           :fee_total

    alias display_ship_total display_delivery_total
    alias_attribute :ship_total, :delivery_total

    # Transient warnings populated by remove_out_of_stock_items! and ensure_available_delivery_rates
    attribute :warnings, default: -> { [] }

    # Removes out-of-stock/discontinued items and populates warnings.
    # Returns self (reloaded if items were removed) with warnings set.
    # Captured before the call because removing items reloads the order, which
    # would drop warnings already recorded upstream.
    # @deprecated Only Carts can auto remove out of stock items
    def remove_out_of_stock_items!
      Spree::Deprecation.warn('Spree::Order#remove_out_of_stock_items! is deprecated and will be removed in Spree 6.1. This method now works only on Spree::Cart objects')

      existing_warnings = warnings
      result = Spree::Carts::RemoveOutOfStockItems.call(cart: self)
      return self unless result.success?

      order, _messages, new_warnings = result.value
      order.warnings = existing_warnings | (new_warnings || [])
      order
    end

    # Standardized column names (renamed in 6.0); legacy readers stay as
    # aliases one release.
    alias_attribute :promo_total, :discount_total
    alias display_promo_total display_discount_total
    alias_attribute :item_count, :total_quantity

    # @deprecated The column is +customer_note+ since 6.0; removed in 6.1.
    def special_instructions
      Spree::Deprecation.warn('Spree::Order#special_instructions is deprecated and will be removed in Spree 6.1. Use #customer_note instead.')
      customer_note
    end

    # @deprecated See {#special_instructions}; removed in 6.1.
    def special_instructions=(value)
      Spree::Deprecation.warn('Spree::Order#special_instructions= is deprecated and will be removed in Spree 6.1. Use #customer_note= instead.')
      self.customer_note = value
    end

    # lock_version (renamed from state_lock_version) drives the API's manual
    # optimistic concurrency (compare client-sent version, 409 on mismatch) —
    # Rails auto-locking must not raise on internal saves.
    self.lock_optimistically = false

    self.whitelisted_ransackable_associations = %w[fulfillments shipments customer created_by approver canceler promotions bill_address ship_address line_items store channel tags seller order_group]
    self.whitelisted_ransackable_attributes = %w[
      completed_at email number status payment_status payment_state fulfillment_status shipment_state delivery_total
      total item_total total_quantity considered_risky channel_id currency coupon_code seller_id order_group_id
    ]
    self.whitelisted_ransackable_scopes = %w[complete incomplete refunded partially_refunded search multi_search]

    # Set to false on admin-initiated flows to suppress customer-facing emails.
    attr_accessor :notify_customer


    STATUSES = %w[draft placed canceled].freeze

    attribute :status, :string, default: 'draft'
    validates :status, inclusion: { in: STATUSES }

    scope :drafts,         -> { where(status: 'draft') }
    scope :not_drafts,     -> { where.not(status: 'draft') }
    scope :placed_orders,  -> { where(status: 'placed') }
    scope :canceled_orders, -> { where(status: 'canceled') }

    acts_as_taggable_on :tags
    acts_as_taggable_tenant :store_id

    def tags=(tags)
      self.tag_list = tags
    end

    ASSOCIATED_CUSTOMER_ATTRIBUTES = [:customer_id, :email, :bill_address_id, :ship_address_id]

    # @deprecated Use {Spree::Purchase::PaymentProcessing#payment_methods};
    #   removed in 6.1.
    def collect_frontend_payment_methods
      Spree::Deprecation.warn('Spree::Order#collect_frontend_payment_methods is deprecated and will be removed in Spree 6.1. Use #payment_methods instead.')
      payment_methods
    end

    include Spree::DeprecatedCustomerAlias

    belongs_to :customer, class_name: "::#{Spree.customer_class}", optional: true, autosave: true
    # The cart this order was completed from (unique — the completion
    # idempotency key). Backoffice draft orders have no cart.
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :order
    # The checkout this order was placed in, when it was placed alongside
    # others — one per seller on a marketplace. A single-seller or first-party
    # only checkout produces a bare order and no group.
    belongs_to :order_group, class_name: 'Spree::OrderGroup', optional: true, inverse_of: :orders
    # Whose sale this is. Nil on the operator's own goods, including the
    # first-party child of a mixed marketplace checkout.
    belongs_to :seller, class_name: 'Spree::Seller', optional: true
    belongs_to :created_by, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :approver, class_name: "::#{Spree.admin_user_class}", optional: true
    belongs_to :canceler, class_name: "::#{Spree.admin_user_class}", optional: true

    belongs_to :preferred_stock_location, class_name: 'Spree::StockLocation', optional: true

    with_options dependent: :destroy do
      has_many :line_items, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::LineItem'
      has_many :payments, class_name: 'Spree::Payment'
      has_many :payment_sessions, inverse_of: :order, class_name: 'Spree::PaymentSession'
      has_many :returns, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::Return'
      has_many :exchanges, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::Exchange'
      has_many :claims, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::Claim'
      has_many :cancellations, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::OrderCancellation'
      has_many :approvals, -> { order(:created_at) }, inverse_of: :order, class_name: 'Spree::OrderApproval'
    end
    has_many :fulfillment_items, inverse_of: :order, class_name: 'Spree::FulfillmentItem'
    has_many :inventory_units, class_name: 'Spree::FulfillmentItem', inverse_of: :order, deprecated: true
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :order, dependent: :destroy
    has_many :return_line_items, through: :returns, class_name: 'Spree::ReturnLineItem', source: :return_line_items
    has_many :variants, through: :line_items
    has_many :products, through: :variants
    # Every refund names the order it puts right — its own payments' refunds
    # stamp it automatically, and a refund against a payment shared by a split
    # checkout names the one child being refunded. Keyed on that column rather
    # than walked through payments, which a grouped order does not own.
    has_many :refunds, class_name: 'Spree::Refund', inverse_of: :order, dependent: :nullify

    # Typed adjustment rows owned by this order (line-, fulfillment- and
    # order-level). See docs/plans/6.0-6.1-split-adjustments.md.
    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :order
    # delete, not destroy: the snapshot is readonly once written, and destroy
    # refuses readonly records. It has no dependents of its own.
    has_one :tax_identifier, class_name: 'Spree::TaxIdentifier', as: :owner,
                             dependent: :delete, inverse_of: :owner
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :order
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :order

    # What the marketplace charged its sellers on this order. Off-order by
    # design: commission never reaches a total the customer pays, so this is a
    # ledger the order merely hosts. See docs/plans/6.0-multi-vendor-marketplace.md.
    has_many :commission_lines, class_name: 'Spree::CommissionLine', dependent: :destroy, inverse_of: :order

    # This order's share of the payments made against its group. Empty on an
    # ungrouped order, whose payments are its own (see #settlement_payments).
    has_many :payment_splits, class_name: 'Spree::PaymentSplit', dependent: :destroy, inverse_of: :order

    has_many :line_item_tax_lines, through: :line_items, source: :tax_lines
    has_many :line_item_discounts, through: :line_items, source: :discounts

    has_many :order_promotions, class_name: 'Spree::OrderPromotion'
    has_many :promotions, through: :order_promotions, class_name: 'Spree::Promotion'

    has_many :fulfillments, -> { order(:created_at, :id) }, class_name: 'Spree::Fulfillment', dependent: :destroy, inverse_of: :order do
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
    accepts_nested_attributes_for :payments, reject_if: :credit_card_nil_payment?
    accepts_nested_attributes_for :fulfillments
    # @deprecated legacy writer — removed in 6.1
    alias shipments_attributes= fulfillments_attributes=

    before_create :link_by_email
    before_update :ensure_updated_fulfillments, :homogenize_line_item_currencies, if: :currency_changed?
    # Record-state deletion eligibility is enforced here, not in ability rules —
    # secret-key API requests never consult CanCanCan (Axis A/B split,
    # docs/plans/decisions.md 2026-08-05).
    before_destroy :ensure_can_be_deleted

    # Shared money/quantity validations live in Spree::Purchase::Validations;
    # only order-specific rules stay here.
    validates :email, presence: true, length: { maximum: 254, allow_blank: true }, email: { allow_blank: true }, if: :require_email
    validates :payment_status,     inclusion: { in: PAYMENT_STATUSES | PAYMENT_STATES, allow_blank: true }
    validates :fulfillment_status, inclusion: { in: FULFILLMENT_STATUSES, allow_blank: true }

    # @deprecated Both warn and run the full recalculation; use
    #   {#recalculate_totals!}. Removed in 6.1.
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
    scope :ready_to_ship, -> { where(fulfillment_status: %w[unfulfilled]) }
    scope :partially_shipped, -> { where(fulfillment_status: %w[partial]) }
    scope :not_shipped, -> { where(fulfillment_status: %w[unfulfilled partial]) }
    scope :shipped, -> { where(fulfillment_status: %w[fulfilled delivered shipped]) }
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
      Spree::Deprecation.warn('Order.register_update_hook is deprecated and will be removed in Spree 6.1')
      update_hooks.add(hook)
    end

    # For compatibility with Calculator::PriceSack
    def amount
      line_items.inject(0.0) { |sum, li| sum + li.amount }
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


    # @deprecated Use {#fulfillment_discount}; removed in 6.1.
    def shipping_discount
      Spree::Deprecation.warn('Spree::Order#shipping_discount is deprecated and will be removed in Spree 6.1. Use #fulfillment_discount instead.')
      fulfillment_discount
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

    # @deprecated machine vocabulary — data-derived bridge for the 6.0
    #   transition, removed in 6.1. An order is "cart-like" while a draft
    #   with no checkout data.
    def cart?
      draft? && !completed? && email.blank? && ship_address_id.blank?
    end

    # Derived, not stored (Decision 8): some but not all fulfillments canceled.
    def partially_canceled?
      !canceled? && fulfillments.canceled.any? && fulfillments.not_canceled.any?
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


    def email_required?
      require_email
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
      payment_required? && fulfillments.count <= 1 && (digital? || !some_digital? || !delivery_step_required?)
    end

    # Check if quick checkout requires an address collection
    # @return [Boolean]
    def quick_checkout_require_address?
      shipping_address_required?
    end

    # @deprecated Use {#recalculate_totals!} for money and {#update_statuses!}
    #   for payment/fulfillment statuses; removed in 6.1.
    def updater
      @updater ||= Spree.order_updater.new(self)
    end

    # Recomputes and persists money totals (item, tax, promotion, delivery)
    # and derived item counts. Convenience for
    # {Spree::Orders::RecalculateTotals}.
    def recalculate_totals!
      Spree.order_recalculate_totals_workflow.call(order: self)
    end

    # Derives and persists payment_status / fulfillment_status from the
    # order's payment, refund and fulfillment records. Convenience for
    # {Spree::Orders::UpdateStatuses}, the sole status writer.
    def update_statuses!
      Spree.order_update_statuses_service.call(order: self)
    end

    # @deprecated Use {#recalculate_totals!}; removed in 6.1.
    def update_with_updater!
      Spree::Deprecation.warn('Spree::Order#update_with_updater! is deprecated and will be removed in Spree 6.1. Use #recalculate_totals! instead.')
      recalculate_totals!
    end

    # @deprecated Use {Spree::Carts::Merge}; removed in 6.1.
    def merger
      @merger ||= Spree::OrderMerger.new(self)
    end


    def allow_cancel?
      return false if !completed? || canceled?

      fulfillment_status.nil? || %w{unfulfilled backorder canceled}.include?(fulfillment_status)
    end
    alias can_cancel? allow_cancel?

    def all_inventory_units_returned?
      inventory_units.all?(&:returned?)
    end

    # Associates the specified user with the order.
    # Delegates to {Spree::Carts::Associate} service.
    #
    # @param customer [Spree.customer_class] the customer to associate with the order
    # @param override_email [Boolean] whether to override the order email with the customer's email
    # @return [Spree::ServiceModule::Result]
    def associate_customer!(customer, override_email = true)
      Spree.cart_associate_service.call(guest_cart: self, customer: customer, override_email: override_email)
    end

    # @deprecated Use {#associate_customer!}; removed in 6.1.
    def associate_user!(user, override_email = true)
      Spree::Deprecation.warn('Spree::Order#associate_user! is deprecated and will be removed in Spree 6.1. Use #associate_customer! instead.')
      associate_customer!(user, override_email)
    end

    def disassociate_customer!
      nullified_attributes = ASSOCIATED_CUSTOMER_ATTRIBUTES.index_with(nil)

      update!(nullified_attributes)
    end

    # @deprecated Use {#disassociate_customer!}; removed in 6.1.
    def disassociate_user!
      Spree::Deprecation.warn('Spree::Order#disassociate_user! is deprecated and will be removed in Spree 6.1. Use #disassociate_customer! instead.')
      disassociate_customer!
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
      tax_provider.estimate(self, **tax_estimate_inputs)
    end

    def create_shipment_tax_charge!
      tax_provider.estimate(self, fulfillments.to_a, **tax_estimate_inputs) if fulfillments.any?
    end

    # Re-prices every line from the catalog.
    #
    # A completed order's money is frozen — re-pricing would rewrite what the
    # customer was actually charged — so this refuses rather than reporting a
    # success it did not deliver. Post-placement price changes belong to the
    # order-change substrate (docs/plans/6.1-order-change-substrate.md).
    #
    # @raise [RuntimeError] when the order is already completed
    # @return [void]
    def update_line_item_prices!
      raise 'cannot re-price a completed order' if completed?

      transaction do
        line_items.reload.each(&:update_price)
        save!
      end
    end

    # Refunds are already netted out of payment_total by
    # Spree::Carts::RecalculateTotals, so returns and claims need no separate
    # term here — the legacy reimbursement payout was the only one that sat
    # outside that sum.
    def outstanding_balance
      if canceled?
        -1 * payment_total
      else
        total - payment_total
      end
    end


    # The payments that settle this order.
    #
    # An order placed in a split checkout has none of its own: the customer
    # made one payment for the whole basket, against the group. Anything asking
    # what money exists for this order — capture on dispatch, refunds, the
    # admin payments panel — reads it here, and reads its own share of it from
    # {#payment_splits}.
    #
    # @return [ActiveRecord::Relation<Spree::Payment>]
    def settlement_payments
      order_group_id.present? ? order_group.payments : payments
    end

    # @return [Boolean] whether this order was placed alongside others in one
    #   checkout, and therefore shares their payment
    def grouped?
      order_group_id.present?
    end

    # This order and any placed alongside it in the same checkout.
    #
    # The set anything counting *checkouts* rather than orders works from — a
    # promotion's usage limit, for one, which must not be spent several times
    # over because a basket happened to span several sellers.
    #
    # @return [Array<Integer>]
    def sibling_order_ids
      return [id] unless grouped?

      order_group.orders.ids
    end

    # This order's share of one payment made against its group.
    #
    # @param payment [Spree::Payment]
    # @return [Spree::PaymentSplit, nil]
    def payment_split_for(payment)
      payment_splits.find_by(payment_id: payment.id)
    end

    def name
      if (address = bill_address || ship_address)
        address.full_name
      end
    end

    def full_name
      @full_name ||= if customer.present? && customer.name.present?
                       customer.full_name
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
        joins(:stock_levels, :product).
        where(Spree::StockLevel.table_name => { backorderable: true }).
        where("#{Spree::StockLevel.table_name}.count_on_hand - #{Spree::StockLevel.table_name}.allocated_count <= ?", 0)
    end

    def can_ship?
      placed?
    end

    def uneditable?
      completed? || canceled?
    end

    # Finalizes an in progress order after checkout is complete.
    # Called after transition to complete state when payments will have been processed
    # @deprecated Completion lives in {Spree::Orders::Complete} (checkout
    #   reaches it through +Spree.carts_complete_workflow+). Removed in 6.1.
    def finalize!
      Spree::Deprecation.warn('Spree::Order#finalize! is deprecated and will be removed in Spree 6.1. Completion runs through Spree.order_complete_workflow (Spree::Orders::Complete).')
      Spree.order_complete_workflow.call(order: self, payment_pending: true)
    end

    def fulfill!
      fulfillments.each { |shipment| shipment.update!(self) if shipment.persisted? }
      save!
      update_statuses!
    end



    def available_payment_methods(store = nil)
      Spree::Deprecation.warn('`Order#available_payment_methods` is deprecated and will be removed in Spree 6.1. Use `payment_methods` instead.')

      @available_payment_methods ||= collect_payment_methods(store)
    end

    def insufficient_stock_lines
      line_items.select(&:insufficient_stock?)
    end

    ##
    # Check to see if any line item variants are discontinued.
    # If so add error and restart checkout.
    # @deprecated Completion validation lives in
    #   {Spree::Checkout::DefaultRequirements} (the +discontinued+ stock
    #   error). Removed in 6.1.
    def ensure_line_item_variants_are_not_discontinued
      Spree::Deprecation.warn('Spree::Order#ensure_line_item_variants_are_not_discontinued is deprecated and will be removed in Spree 6.1. Completion validation lives in Spree::Checkout::Requirements.')
      if line_items.any? { |li| !li.variant || li.variant.discontinued? }
        errors.add(:base, Spree.t(:discontinued_variants_present))
        false
      else
        true
      end
    end

    # @deprecated Completion validation lives in
    #   {Spree::Checkout::DefaultRequirements} (the +out_of_stock+ stock
    #   error). Removed in 6.1.
    def ensure_line_items_are_in_stock
      Spree::Deprecation.warn('Spree::Order#ensure_line_items_are_in_stock is deprecated and will be removed in Spree 6.1. Completion validation lives in Spree::Checkout::Requirements.')
      if insufficient_stock_lines.present?
        errors.add(:base, Spree.t(:insufficient_stock_lines_present))
        false
      else
        true
      end
    end

    def use_all_coupon_codes
      Spree::Deprecation.warn('Spree::Order#use_all_coupon_codes is deprecated and will be removed in Spree 6.1. Use Spree::CouponCodes::CouponCodesHandler instead.')
      Spree::CouponCodes::CouponCodesHandler.new(order: self).use_all_codes
    end

    normalizes :coupon_code, with: ->(code) { code.to_s.strip.downcase.presence }

    def can_add_coupon?
      Spree::Deprecation.warn('Spree::Order#can_add_coupon? is deprecated and will be removed in Spree 6.1. Use Spree::Promotion.order_activatable? instead.')
      Spree::Promotion.order_activatable?(self)
    end

    def shipped?
      %w(partial shipped fulfilled delivered).include?(fulfillment_status)
    end

    # True when every fulfillment has left the merchant's hands — the signal
    # order.fulfilled publishes on. `delivered` counts: it is downstream of
    # fulfilled, so a delivered order must not read as un-fulfilled.
    def fully_fulfilled?
      fulfillments.fulfilled_or_delivered.size == fulfillments.size
    end

    # True when every fulfillment reached confirmed receipt — the signal
    # order.delivered publishes on.
    def fully_delivered?
      total = fulfillments.size
      total.positive? && fulfillments.delivered.size == total
    end

    # @deprecated Use {#fully_fulfilled?}; removed in 6.1.
    def fully_shipped?
      Spree::Deprecation.warn('Spree::Order#fully_shipped? is deprecated and will be removed in Spree 6.1. Use #fully_fulfilled? instead.')
      fully_fulfilled?
    end

    def rebuild_fulfillments!
      discounts.for_fulfillments.delete_all
      tax_lines.for_fulfillments.delete_all
      fees.for_fulfillments.delete_all

      shipment_ids = fulfillments.map(&:id)
      DeliveryRate.where(fulfillment_id: shipment_ids).delete_all

      fulfillments.delete_all

      # Inventory Units which are not associated to any shipment (unshippable)
      # and are not returned or shipped should be deleted
      fulfillment_items.on_hand_or_backordered.delete_all

      self.fulfillments = order_routing_strategy.for_allocation.map do |package|
        package.to_fulfillment.tap { |fulfillment| fulfillment.address_id = ship_address_id }
      end
    end

    # @deprecated Use {#rebuild_fulfillments!}; removed in 6.1.
    def create_proposed_fulfillments
      Spree::Deprecation.warn('Spree::Order#create_proposed_fulfillments is deprecated and will be removed in Spree 6.1. Use #rebuild_fulfillments! instead.')
      rebuild_fulfillments!
    end

    # @deprecated Use {#rebuild_fulfillments!}; removed in 6.1.
    def create_proposed_shipments
      Spree::Deprecation.warn('Spree::Order#create_proposed_shipments is deprecated and will be removed in Spree 6.1. Use #rebuild_fulfillments! instead.')
      rebuild_fulfillments!
    end

    # @deprecated Use {#delivery_step_required?}; removed in 6.1.
    def delivery_required?
      Spree::Deprecation.warn('Spree::Order#delivery_required? is deprecated and will be removed in Spree 6.1. Use #delivery_step_required? (delivery-step applicability) or #shipping_address_required? (address collection) instead.')
      delivery_step_required?
    end

    # @deprecated Use {#shipping_address_required?}; removed in 6.1.
    def requires_ship_address?
      Spree::Deprecation.warn('Spree::Order#requires_ship_address? is deprecated and will be removed in Spree 6.1. Use #shipping_address_required? instead.')
      shipping_address_required?
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

    # Returns line items that have no delivery rates
    #
    # Deliberately not memoized: callers destroy fulfillments between reads
    # (see {#ensure_available_delivery_rates}), so a cached value would
    # describe fulfillments that no longer exist.
    #
    # @return [Array<Spree::LineItem>]
    def line_items_without_delivery_rates
      fulfillments.map do |fulfillment|
        fulfillment.manifest.map(&:line_item) if fulfillment.delivery_rates.blank?
      end.flatten.compact
    end

    # @deprecated Use {#line_items_without_delivery_rates}; removed in 6.1.
    def line_items_without_shipping_rates
      Spree::Deprecation.warn('Spree::Order#line_items_without_shipping_rates is deprecated and will be removed in Spree 6.1. Use #line_items_without_delivery_rates instead.')
      line_items_without_delivery_rates
    end

    # Checks if all line items cannot be shipped
    #
    # @returns Boolean
    def all_line_items_invalid?
      line_items_without_delivery_rates.size == line_items.count
    end

    def apply_free_shipping_promotions
      Spree::PromotionHandler::FreeShipping.new(self).activate
      recalculate_totals!
    end

    # Applies user promotions when login after filling the cart
    def apply_unassigned_promotions
      ::Spree::PromotionHandler::Cart.new(self).activate
    end

    # Drops stale fulfillments so they are rebuilt from current items.
    def ensure_updated_fulfillments
      if fulfillments.any? && !completed?
        fulfillments.destroy_all
        update_column(:delivery_total, 0)

        # Manually publish update event since update_column bypasses callbacks
        publish_event('order.updated')
      end
    end

    # @deprecated Use {#ensure_updated_fulfillments}; removed in 6.1.
    def ensure_updated_shipments
      Spree::Deprecation.warn('Spree::Order#ensure_updated_fulfillments is deprecated and will be removed in Spree 6.1. Use #ensure_updated_fulfillments instead.')
      ensure_updated_fulfillments
    end

    # Re-quotes every fulfillment for the given audience.
    #
    # @param audience [Symbol] {Spree::DeliveryMethod::STOREFRONT} (default)
    #   or {Spree::DeliveryMethod::BACKOFFICE}
    # @return [Array<Array<Spree::DeliveryRate>>]
    def refresh_delivery_rates(audience = DeliveryMethod::STOREFRONT)
      fulfillments.map { |fulfillment| fulfillment.refresh_rates(audience) }
    end

    # @deprecated Use {#refresh_delivery_rates}; removed in 6.1.
    def refresh_shipment_rates(audience = DeliveryMethod::STOREFRONT)
      Spree::Deprecation.warn('Spree::Order#refresh_shipment_rates is deprecated and will be removed in Spree 6.1. Use #refresh_delivery_rates instead.')
      refresh_delivery_rates(audience)
    end

    def set_shipments_cost
      Spree::Deprecation.warn('Spree::Order#set_shipments_cost is deprecated and will be removed in Spree 6.1l. Please use set_fulfillments_cost instead')
      set_fulfillments_cost
    end

    def set_fulfillments_cost
      fulfillments.each(&:update_amounts)
      recalculate_totals!
    end

    def shipping_method
      Spree::Deprecation.warn('Spree::Order#shipping_method is deprecated and will be removed in Spree 6.1. Please use Spree::Order#delivery_method')
      delivery_method
    end

    # Returns first available delivery method from the fulfillments
    # Useful for analytics and CSV exports
    # @return [Spree::DeliveryMethod]
    def delivery_method
      # This query will select the first available delivery method from the fulfillments.
      # It will use subquery to first select the delivery method id from the fulfillments' selected_delivery_rate.
      Spree::DeliveryMethod.
        where(id: fulfillments.with_selected_delivery_method.limit(1).pluck(:delivery_method_id)).
        limit(1).
        first
    end

    def is_risky?
      !payments.risky.empty?
    end

    # Cancels the order and records the canceler.
    # Delegates to {Spree::Orders::Cancel} workflow.
    #
    # @deprecated Call {Spree.order_cancel_workflow} directly — it exposes the
    #   full cancellation vocabulary (reason, note, restock_items,
    #   refund_payments, notify_customer) this wrapper cannot pass through.
    # @param user [Spree.customer_class, nil] the user who canceled the order
    # @param canceled_at [Time, nil] the time of cancellation (defaults to current time)
    # @return [Spree::ServiceModule::Result]
    def canceled_by(user, canceled_at = nil)
      Spree::Deprecation.warn('Spree::Order#canceled_by is deprecated and will be removed in Spree 6.1. Use Spree.order_cancel_workflow (Spree::Orders::Cancel) instead.')
      Spree.order_cancel_workflow.call(order: self, canceler: user, canceled_at: canceled_at)
    end

    # Machine-free lifecycle: cancellation runs through the
    # {Spree::Orders::Cancel} workflow (which also records a
    # Spree::OrderCancellation row); resume flips +status+ back and runs
    # the same side effects the machine transition ran.
    def cancel
      Spree.order_cancel_workflow.call(order: self).success?
    end

    def cancel!
      cancel || raise(ActiveRecord::RecordInvalid.new(self))
    end

    def resume
      Spree.order_resume_workflow.call(order: self).success?
    end

    def resume!
      resume || raise(ActiveRecord::RecordInvalid.new(self))
    end

    # Approves the order and records the approver.
    # Delegates to {Spree::Orders::Approve} service.
    #
    # @param user [Spree.customer_class, nil] the user who approved the order
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

    def collect_backend_payment_methods
      store.payment_methods.active.select { |pm| pm.available_for_order?(self) }
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
      Spree::Deprecation.warn('Spree::Order#cart_promo_total is deprecated and will be removed in Spree 6.1. Please use order.cart.discount_total instead')
      discounts.promotion.nonzero.for_line_items.sum(:amount)
    end

    def has_free_shipping?
      discounts.promotion.for_fulfillments.exists?
    end

    def to_csv(_store = nil)
      custom_fields_for_csv ||= Spree::CustomFieldDefinition.for_resource_type('Spree::Order').order(:namespace, :key).map do |mf_def|
        custom_fields.find { |mf| mf.custom_field_definition_id == mf_def.id }&.csv_value
      end

      csv_lines = []
      line_items.each_with_index do |line_item, index|
        csv_lines << Spree::CSV::OrderLineItemPresenter.new(self, line_item, index, custom_fields_for_csv).call
      end
      csv_lines
    end

    def all_line_items
      Spree::Deprecation.warn('Spree::Order#all_line_items is deprecated and will be removed in Spree 6.1. Please use Spree::Order#line_items instead')
      line_items
    end

    private

    def ensure_can_be_deleted
      return true if can_be_deleted?

      errors.add(:base, Spree.t(:order_cannot_be_deleted))
      throw :abort
    end

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
      self.email = customer.email if customer
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

    def ensure_available_delivery_rates
      # Captured before destroy_all — afterwards there are no fulfillments
      # left to derive the undeliverable items from.
      undeliverable_line_items = line_items_without_delivery_rates

      if fulfillments.empty? || undeliverable_line_items.present?
        # After this point, order redirects back to 'address' state and asks user to pick a proper address
        # Therefore, shipments are not necessary at this point.
        fulfillments.destroy_all

        if undeliverable_line_items.present?
          errors.add(:base, Spree.t(:products_cannot_be_shipped, product_names: undeliverable_line_items.map(&:name).to_sentence))
          self.warnings |= undeliverable_line_items.map do |line_item|
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

    def collect_payment_methods
      Spree::Deprecation.warn('`Order#collect_payment_methods` is deprecated and will be removed in Spree 6.1. Use `payment_methods` instead.')

      store.payment_methods.active.storefront_visible.select { |pm| pm.available_for_order?(self) }
    end

    def credit_card_nil_payment?(attributes)
      payments.store_credits.present? && attributes[:amount].to_f.zero?
    end

    def recalculate_store_credit_payment
      recalculate_totals! if using_store_credit?

      if gift_card.present?
        recalculate_gift_card
      elsif using_store_credit?
        Spree.store_credit_apply_service.call(order: self)
      end
    end

  end
end
