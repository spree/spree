module Spree
  # The pre-completion (shopping + checkout) phase of a purchase. Completing
  # checkout copies a cart into an immutable {Spree::Order}; the cart is
  # retained with +completed_at+ set. Carts have no status column —
  # +completed_at+ is the only lifecycle marker.
  #
  # There is no checkout state machine: progression is computed by
  # Spree::Checkout::Requirements against cart data, and recalculation happens
  # on the writes that matter (items, addresses, market) instead of on state
  # transitions. See docs/plans/6.0-cart-order-split.md.
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

    # Concurrency is manual (the API's OrderLock semantics — compare
    # client-sent version, 409 on mismatch); Rails auto-locking must not
    # raise on internal saves.
    self.lock_optimistically = false

    # Single consolidated metadata JSON column (docs/plans/decisions.md
    # 2026-03-16 "Consolidate metadata").
    attribute :metadata, default: -> { {} }
    attribute :accept_marketing, :boolean, default: false

    # Standardized column names; legacy readers stay as aliases one release.
    alias_attribute :item_count, :total_quantity
    alias_attribute :promo_total, :discount_total

    money_methods :item_total, :adjustment_total, :included_tax_total, :additional_tax_total,
                  :discount_total, :fee_total, :delivery_total, :total, :payment_total, :outstanding_balance,
                  :tax_total, :pre_tax_item_amount, :pre_tax_total, :amount_due

    alias display_promo_total display_discount_total
    alias display_ship_total display_delivery_total
    alias_attribute :ship_total, :delivery_total

    belongs_to :customer, class_name: "::#{Spree.user_class}", optional: true
    belongs_to :ship_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
    belongs_to :bill_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
    # Normalizes like the legacy Order writer so lookups stay case-insensitive.
    def coupon_code=(code)
      normalized = begin
        code.strip.downcase
      rescue StandardError
        nil
      end
      super(normalized)
    end

    # Pickup location choice is a preference (mirrors the admin-user
    # preference of the same name), copied to the order column at completion.
    preference :stock_location_id, :integer, nullable: true
    alias_method :assign_stock_location_id_preference, :preferred_stock_location_id=

    # Accepts the public prefixed ID (+sloc_...+) or a raw ID; validates the
    # location is pickup-enabled so the storefront can only select real
    # pickup locations.
    def preferred_stock_location_id=(value)
      if value.blank?
        assign_stock_location_id_preference(nil)
        return
      end

      location = if Spree::PrefixedId.prefixed_id?(value)
                   Spree::StockLocation.pickup_enabled.find_by_prefix_id!(value)
                 else
                   Spree::StockLocation.pickup_enabled.find(value)
                 end
      assign_stock_location_id_preference(location.id)
    end

    # @return [Spree::StockLocation, nil]
    def preferred_stock_location
      Spree::StockLocation.find_by(id: preferred_stock_location_id)
    end

    alias_method :user, :customer
    alias_method :user=, :customer=
    alias_attribute :user_id, :customer_id
    alias_method :shipping_address, :ship_address
    alias_method :shipping_address=, :ship_address=
    alias_attribute :shipping_address_id, :ship_address_id
    alias_method :billing_address, :bill_address
    alias_method :billing_address=, :bill_address=
    alias_attribute :billing_address_id, :bill_address_id
    alias_attribute :customer_note, :special_instructions

    has_many :line_items, -> { order(:created_at) }, class_name: 'Spree::LineItem', inverse_of: :cart, dependent: :destroy
    has_many :variants, through: :line_items
    has_many :products, through: :variants
    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :cart
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :cart
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :cart
    has_many :fulfillments, class_name: 'Spree::Fulfillment', dependent: :destroy, inverse_of: :cart do
      def states
        pluck(:status).uniq
      end
    end
    has_many :shipments, class_name: 'Spree::Fulfillment', inverse_of: :cart, deprecated: true
    has_many :fulfillment_items, through: :fulfillments, class_name: 'Spree::FulfillmentItem'
    has_many :order_promotions, class_name: 'Spree::OrderPromotion', inverse_of: :cart, dependent: :destroy
    has_many :promotions, through: :order_promotions, class_name: 'Spree::Promotion'
    has_many :payments, class_name: 'Spree::Payment', inverse_of: :cart, dependent: :destroy
    has_many :payment_sessions, class_name: 'Spree::PaymentSession', inverse_of: :cart, dependent: :destroy
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :cart, dependent: :destroy
    has_one :order, class_name: 'Spree::Order', inverse_of: :cart

    alias items line_items

    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :ship_address, :bill_address
    accepts_nested_attributes_for :payments
    alias_method :shipping_address_attributes=, :ship_address_attributes=
    alias_method :billing_address_attributes=, :bill_address_attributes=

    validates :store, :currency, presence: true
    scope :complete, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }

    self.whitelisted_ransackable_attributes = %w[email completed_at token updated_at]

    attr_accessor :temporary_address, :use_shipping, :skip_market_resolution

    before_validation :clone_shipping_address, if: :use_shipping?

    before_validation :resolve_market_from_currency, if: -> { persisted? && currency_changed? && !skip_market_resolution }

    delegate :name, to: :customer, prefix: true, allow_nil: true

    # Public cart identifier on the wire (orders keep R-numbers; carts are
    # identified by token).
    def number
      token
    end

    # @return [Boolean]
    def completed?
      completed_at.present?
    end
    alias complete? completed?

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

    # Checkout begins once any checkout-only data is present (email or a
    # shipping address). Drives stock-reservation dispatch.
    def in_checkout?
      !completed? && (email.present? || ship_address_id.present?)
    end

    # Reservation dispatch parity with the order-based checkout.
    def cart?
      !in_checkout?
    end

    # @return [Boolean] carts are never canceled — completion or expiry only
    def canceled?
      false
    end

    # Recomputes and persists money totals (item, tax, promotion, delivery)
    # and derived item counts. Convenience for
    # {Spree::Carts::RecalculateTotals}.
    def recalculate_totals!
      Spree.cart_recalculate_totals_workflow.call(cart: self)
    end

    def shipping_eq_billing_address?
      bill_address == ship_address
    end

    def use_shipping?
      use_shipping.in?([true, 'true', '1'])
    end

    def quantity
      line_items.sum(:quantity)
    end

    def outstanding_balance
      total - payment_total
    end

    def outstanding_balance?
      outstanding_balance != 0
    end

    # Whether every line item can be delivered without a shipping address
    # (digital-only carts skip the address/delivery steps).
    def delivery_required?
      line_items.any? && !digital?
    end

    def paid?
      total.positive? && payment_total >= total
    end

    def backordered?
      fulfillment_items.any?(&:backordered?)
    end

    # Fulfillments never dispatch from a cart — determine_state reports
    # 'pending' until completion copies them onto an order.
    def can_ship?
      false
    end

    def guest_checkout_disallowed?
      return false if customer.present?

      resolved_channel = channel || store&.default_channel
      return false unless resolved_channel.respond_to?(:guest_checkout_enabled?)

      !resolved_channel.guest_checkout_enabled?
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
      StateChange.where(stateful_type: %w[Spree::Shipment Spree::Fulfillment], stateful_id: fulfillment_ids).delete_all
      DeliveryRate.where(fulfillment_id: fulfillment_ids).delete_all
      fulfillments.delete_all
      fulfillment_items.reset

      self.fulfillments = Spree::Stock::Coordinator.new(self).shipments.map do |fulfillment|
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
    # order-side ensure_available_shipping_rates).
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

    def ensure_available_shipping_rates
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
    alias create_proposed_fulfillments rebuild_fulfillments!

    # @deprecated Use {#create_proposed_fulfillments}; removed in 6.1.
    def create_proposed_shipments
      Spree::Deprecation.warn('Spree::Cart#create_proposed_shipments is deprecated and will be removed in Spree 6.1. Use #create_proposed_fulfillments instead.')
      rebuild_fulfillments!
    end

    def ensure_updated_fulfillments
      rebuild_fulfillments! unless completed?
    end

    # @deprecated Use {#ensure_updated_fulfillments}; removed in 6.1.
    def ensure_updated_shipments
      Spree::Deprecation.warn('Spree::Cart#ensure_updated_shipments is deprecated and will be removed in Spree 6.1. Use #ensure_updated_fulfillments instead.')
      ensure_updated_fulfillments
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


    def amount_due
      [outstanding_balance - total_applied_store_credit, 0].max
    end

    # Serializer surface: available payment methods for this cart.
    def payment_methods
      collect_frontend_payment_methods
    end

    def collect_frontend_payment_methods
      store.payment_methods.active.available_on_front_end.select { |payment_method| payment_method.available_for_order?(self) }
    end

    # Binds a signing-in user to the cart (mirrors Order#associate_user!).
    def associate_user!(user, override_email = true)
      self.customer = user
      self.email = user.email if override_email || email.blank?
      self.bill_address ||= user.bill_address if user.bill_address&.valid?
      self.ship_address ||= user.ship_address if user.ship_address&.valid? && delivery_required?
      save! if persisted?
    end

    # Merges another cart into this one through the swappable merge strategy
    # (Spree::Dependencies.cart_merge_strategy).
    def merge!(other_cart, user = nil)
      Spree::Dependencies.cart_merge_strategy.constantize.call(cart: self, other_cart: other_cart, user: user)
      reload
    end

    # Transient warnings populated by remove_out_of_stock_items!
    attribute :warnings, default: -> { [] }

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

    private

    # Same-object copy as Spree::Order — the two FKs share one address row.
    def clone_shipping_address
      self.bill_address = ship_address if ship_address
      true
    end
  end
end
