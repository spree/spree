module Spree
  # The pre-completion (shopping + checkout) phase of a purchase. Completing
  # checkout copies a cart into an immutable {Spree::Order}; the cart is
  # retained with +completed_at+ set. Carts have no status column —
  # +completed_at+ is the only lifecycle marker.
  class Cart < Spree.base_class
    has_prefix_id :cart

    # cart.created / cart.updated / cart.deleted — the abandonment-tooling
    # signal (parity with 5.x, where incomplete orders emitted order.*).
    # Payload serializes through the V3 cart serializer by convention.
    publishes_lifecycle_events

    has_secure_token

    extend Spree::DisplayMoney

    include Spree::SingleStoreResource
    include Spree::Purchase::Channel
    include Spree::Purchase::Company
    include Spree::Purchase::Market
    include Spree::Purchase::Currency
    include Spree::Purchase::Locale
    include Spree::Purchase::CheckoutSteps
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

    # Concurrency is manual (the API's OrderLock semantics — compare
    # client-sent version, 409 on mismatch); Rails auto-locking must not
    # raise on internal saves.
    self.lock_optimistically = false

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata").
    attribute :metadata, default: -> { {} }
    attribute :accept_marketing, :boolean, default: false

    # Transient warnings populated by remove_out_of_stock_items!
    attribute :warnings, default: -> { [] }

    money_methods :item_total, :adjustment_total, :included_tax_total, :additional_tax_total,
                  :discount_total, :fee_total, :delivery_total, :total, :payment_total, :outstanding_balance,
                  :tax_total, :pre_tax_item_amount, :pre_tax_total, :amount_due

    alias display_promo_total display_discount_total
    alias display_ship_total display_delivery_total
    alias_attribute :ship_total, :delivery_total

    belongs_to :customer, class_name: "::#{Spree.customer_class}", optional: true
    # Order-parity aliases — shared Cart/Order code (services, Purchase
    # concerns) reads #user; the cart column is customer_id.
    alias_method :user, :customer
    alias_method :user=, :customer=
    alias_attribute :user_id, :customer_id
    # Codes are stored stripped + lowercased so lookups stay case-insensitive;
    # normalizes also applies to finder values.
    normalizes :coupon_code, with: ->(code) { code.to_s.strip.downcase.presence }

    # Pickup location choice, copied to the order at completion. Prefixed-ID
    # resolution and the pickup-enabled rule live in Spree::Carts::Update,
    # matching the Orders::Create twin.
    belongs_to :preferred_stock_location, class_name: 'Spree::StockLocation', optional: true

    has_many :line_items, -> { order(:created_at) }, class_name: 'Spree::LineItem', inverse_of: :cart, dependent: :destroy
    has_many :variants, through: :line_items
    has_many :products, through: :variants
    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :cart
    has_one :tax_identifier, class_name: 'Spree::TaxIdentifier', dependent: :destroy, inverse_of: :cart
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :cart
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :cart
    has_many :fulfillments, class_name: 'Spree::Fulfillment', dependent: :destroy, inverse_of: :cart do
      def states
        pluck(:status).uniq
      end
    end
    has_many :fulfillment_items, through: :fulfillments, class_name: 'Spree::FulfillmentItem'
    has_many :order_promotions, class_name: 'Spree::OrderPromotion', inverse_of: :cart, dependent: :destroy
    has_many :promotions, through: :order_promotions, class_name: 'Spree::Promotion'
    has_many :payments, class_name: 'Spree::Payment', inverse_of: :cart, dependent: :destroy
    has_many :payment_sessions, class_name: 'Spree::PaymentSession', inverse_of: :cart, dependent: :destroy
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :cart, dependent: :destroy
    has_one :order, class_name: 'Spree::Order', inverse_of: :cart

    alias items line_items

    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }

    # Shape only — email presence during checkout is a Checkout::Requirements
    # concern, never a model validation (guest carts have no email).
    validates :email, length: { maximum: 254, allow_blank: true }, email: { allow_blank: true }

    self.whitelisted_ransackable_attributes = %w[email completed_at token updated_at]

    before_update :ensure_updated_fulfillments, :homogenize_line_item_currencies, if: :currency_changed?

    delegate :name, to: :customer, prefix: true, allow_nil: true

    # @deprecated Store API bridge — carts have no order-style number; the
    #   prefixed ID is the identifier. Removed from the API in 6.1.
    # @return [String]
    def number
      prefixed_id
    end

    # A completed cart is an immutable audit record — post-checkout life
    # belongs to the order. Blocks save/update_columns/touch/destroy at the
    # model level; the completion write itself passes because it fires while
    # the persisted completed_at is still nil.
    def readonly?
      super || (completed_at.present? && !completed_at_changed?)
    end

    # @return [Boolean] whether a completion attempt currently holds this cart
    def completing?
      completing_at.present?
    end

    # Recomputes and persists money totals (item, tax, promotion, delivery)
    # and derived item counts. Convenience for
    # {Spree::Carts::RecalculateTotals}.
    def recalculate_totals!
      Spree.cart_recalculate_totals_workflow.call(cart: self)
    end

    def outstanding_balance
      total - payment_total
    end

    # Idempotent delivery-proposal rebuild — replaces the destructive
    # order-side create_proposed_fulfillments. Open fulfillments are rebuilt from
    # the current items/address; nothing here touches a completed cart.
    def rebuild_fulfillments!
      return if completed?

      discounts.for_fulfillments.delete_all
      tax_lines.for_fulfillments.delete_all
      fees.for_fulfillments.delete_all

      fulfillment_ids = fulfillments.map(&:id)
      DeliveryRate.where(fulfillment_id: fulfillment_ids).delete_all
      fulfillments.delete_all
      fulfillment_items.reset

      self.fulfillments = Spree::Stock::Coordinator.new(self).fulfillments.map do |fulfillment|
        fulfillment.address_id = ship_address_id
        fulfillment.order = nil
        fulfillment.cart = self
        fulfillment
      end
      prune_undeliverable_fulfillments!
      fulfillments.reload
    end

    # Drops proposals that found no delivery rates and surfaces a
    # delivery_unavailable warning per affected line item (parity with the
    # order-side ensure_available_delivery_rates).
    def prune_undeliverable_fulfillments!
      undeliverable = fulfillments.reload.select { |fulfillment| fulfillment.delivery_rates.empty? }
      return if undeliverable.empty?

      affected_line_items = undeliverable.flat_map(&:line_items).uniq
      undeliverable.each(&:destroy)
      self.warnings |= affected_line_items.map do |line_item|
        {
          code: 'delivery_unavailable',
          message: Spree.t('cart_line_item.delivery_unavailable', li_name: line_item.name),
          line_item_id: line_item.prefixed_id
        }
      end
    end

    def ensure_available_delivery_rates
      if fulfillments.empty? || fulfillments.any? { |fulfillment| fulfillment.delivery_rates.blank? }
        errors.add(:base, Spree.t(:items_cannot_be_shipped))
        return false
      end
      true
    end

    def set_fulfillments_cost
      fulfillments.each(&:update_amounts)
      self.delivery_total = fulfillments.reload.to_a.sum(&:cost)
      update_columns(
        delivery_total: delivery_total,
        total: item_total + delivery_total + adjustment_total,
        updated_at: Time.current
      )
    end
    alias set_shipments_cost set_fulfillments_cost

    def ensure_updated_fulfillments
      rebuild_fulfillments! unless completed?
    end

    # Re-prices, re-taxes and rebuilds delivery proposals — the
    # recalculation-on-write replacement for transition-triggered rebuilds.
    # Called by Carts::Update after address/market changes.
    def recalculate_for_address_change!
      line_items.reload.each(&:update_price)
      rebuild_fulfillments!
      set_fulfillments_cost
      recalculate_totals!
    end

    # Binds a signing-in customer to the cart through the swappable associate
    # service (same seam Order#associate_customer! uses).
    def associate_customer!(customer, override_email = true)
      Spree.cart_associate_service.call(guest_cart: self, customer: customer, override_email: override_email)
    end

    # @deprecated Use {#associate_customer!}; removed in 6.1.
    def associate_user!(user, override_email = true)
      Spree::Deprecation.warn('Spree::Cart#associate_user! is deprecated and will be removed in Spree 6.1. Use #associate_customer! instead.')
      associate_customer!(user, override_email)
    end

    # Merges another cart into this one through the swappable merge workflow
    # (Spree::Dependencies.cart_merge_workflow).
    def merge!(other_cart, customer = nil)
      Spree.cart_merge_workflow.call(cart: self, other_cart: other_cart, customer: customer)
      reload
    end

    # Removes out-of-stock/discontinued items and populates warnings
    # (mirrors Order#remove_out_of_stock_items!).
    def remove_out_of_stock_items!
      existing_warnings = warnings
      result = Spree::Carts::RemoveOutOfStockItems.call(cart: self)
      return self unless result.success?

      cart, _messages, new_warnings = result.value
      cart.warnings = existing_warnings | (new_warnings || [])
      cart
    end

  end
end
