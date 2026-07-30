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

    extend Spree::DisplayMoney
    money_methods :item_total, :adjustment_total, :included_tax_total, :additional_tax_total,
                  :discount_total, :fee_total, :delivery_total, :total, :payment_total, :outstanding_balance,
                  :tax_total, :pre_tax_item_amount, :pre_tax_total, :amount_due
    alias display_promo_total display_discount_total
    alias display_ship_total display_delivery_total
    alias_attribute :ship_total, :delivery_total

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :market, class_name: 'Spree::Market'
    belongs_to :channel, class_name: 'Spree::Channel'
    belongs_to :customer, class_name: "::#{Spree.user_class}", optional: true
    belongs_to :ship_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
    belongs_to :bill_address, class_name: 'Spree::Address', optional: true, dependent: :destroy
    belongs_to :gift_card, class_name: 'Spree::GiftCard', optional: true
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

    before_validation :ensure_market_presence
    before_validation :ensure_channel_presence

    validates :store, :currency, presence: true
    validate :currency_must_be_supported_by_store

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

    class_attribute :update_hooks, default: Set.new

    # Mirrors Spree::Order.register_update_hook for cart-side hooks.
    def self.register_update_hook(hook)
      update_hooks.add(hook)
    end

    # Legacy extensions register their hooks on Spree::Order and expect them
    # to fire during checkout — include those alongside cart-registered ones.
    def update_hooks
      self.class.update_hooks | Spree::Order.update_hooks
    end

    def updater
      @updater ||= Spree::CartUpdater.new(self)
    end

    # Recomputes and persists money totals (item, tax, promotion, delivery)
    # and derived item counts. Convenience for
    # {Spree::Carts::RecalculateTotals}.
    def recalculate_totals!
      Spree::Carts::RecalculateTotals.call(cart: self)
    end

    # @deprecated Use {#recalculate_totals!}; removed in 6.1.
    def update_with_updater!
      Spree::Deprecation.warn('Spree::Cart#update_with_updater! is deprecated and will be removed in Spree 6.1. Use #recalculate_totals! instead.')
      recalculate_totals!
    end

    # The address tax is computed against, honoring the tax_using_ship_address
    # preference (mirrors Spree::Order#tax_address).
    #
    # @return [Spree::Address, nil]
    def tax_address
      Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
    end

    # @return [Spree::Zone, nil]
    def tax_zone
      Spree::Zone.match(tax_address) || Spree::Zone.default_tax
    end

    def currency
      self[:currency] || store&.default_currency
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

    def payment_required?
      total.to_f > 0.0
    end

    def confirmation_required?
      Spree::Config[:always_include_confirm_step] ||
        payments.valid.map(&:payment_method).compact.any?(&:payment_profiles_supported?)
    end

    # Whether every line item can be delivered without a shipping address
    # (digital-only carts skip the address/delivery steps).
    def delivery_required?
      line_items.any? && !digital?
    end

    def digital?
      line_items.any? && line_items.includes(variant: :product).all? { |line_item| line_item.variant.product.digital? }
    end

    def requires_ship_address?
      !digital?
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
      updater.update_delivery_total
      updater.persist_totals
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

    # Duck-type parity with the order-side inventory hooks: carts have no
    # named steps, only the delivery requirement.
    def has_checkout_step?(step)
      step.to_s == 'delivery' ? delivery_required? : true
    end

    # Checkout-step introspection (mirrors Order::Checkout, computed from
    # requirements)
    def checkout_steps
      steps = ['address']
      steps << 'delivery' if delivery_required?
      steps << 'payment' if payment_required?
      steps << 'confirm' if confirmation_required?
      steps << 'complete'
      steps
    end

    def current_checkout_step
      return 'complete' if completed?

      first_unmet = Spree::Checkout::Requirements.new(self).call.first
      step = first_unmet ? first_unmet[:step].to_s : 'complete'
      # `cart` (missing line items) is not a customer-facing checkout step
      step == 'cart' ? 'address' : step
    end

    def completed_checkout_steps
      steps = checkout_steps.reject { |step| step == 'complete' }
      return steps if current_checkout_step == 'complete'

      index = steps.index(current_checkout_step) || 0
      steps.first(index)
    end

    def available_store_credits
      return Spree::StoreCredit.none if customer.nil?

      customer.store_credits.for_store(store).where(currency: currency).available.sort_by(&:amount_remaining).reverse
    end

    def total_available_store_credit
      return 0.0 unless customer

      customer.total_available_store_credit(currency, store)
    end

    def could_use_store_credit?
      return false if store.payment_methods.store_credit.available.empty?

      total_available_store_credit > 0
    end

    def total_applied_store_credit
      payments.store_credits.valid.sum(:amount)
    end

    def covered_by_store_credit?
      customer.present? && total_applied_store_credit.positive? && total_applied_store_credit >= total
    end

    def using_store_credit?
      total_applied_store_credit.positive?
    end

    def display_total_applied_store_credit
      Spree::Money.new(-total_applied_store_credit, currency: currency)
    end

    def order_total_after_store_credit
      total - total_applied_store_credit
    end

    def total_minus_store_credits
      total - total_applied_store_credit
    end

    def tax_total
      included_tax_total + additional_tax_total
    end

    def pre_tax_item_amount
      line_items.sum(:pre_tax_amount)
    end

    def pre_tax_total
      pre_tax_item_amount + fulfillments.sum(:pre_tax_amount)
    end

    def amount_due
      [outstanding_balance - total_applied_store_credit, 0].max
    end

    def gift_card_total
      return 0.to_d unless gift_card.present?

      store_credit_ids = payments.store_credits.valid.pluck(:source_id)
      Spree::StoreCredit.where(id: store_credit_ids, originator: gift_card).sum(:amount)
    end

    def apply_gift_card(gift_card)
      Spree.gift_card_apply_service.call(gift_card: gift_card, order: self)
    end

    def remove_gift_card
      Spree.gift_card_remove_service.call(order: self)
    end

    def redeem_gift_card
      return unless gift_card.present?

      Spree.gift_card_redeem_service.call(gift_card: gift_card)
    end

    # See Spree::Order::GiftCard#recalculate_gift_card — same in-lock
    # read-compute-write to keep the payment amount in sync with the total.
    def recalculate_gift_card
      return unless gift_card.present?

      payment = payments.checkout.store_credits.where(source: gift_card.store_credits).first
      return unless payment

      gift_card.with_lock do
        new_amount = [gift_card.amount_remaining + payment.amount, total].min
        next if payment.amount == new_amount

        difference = new_amount - payment.amount
        payment.update_column(:amount, new_amount)
        payment.source.update_column(:amount, new_amount)
        gift_card.amount_used += difference
        gift_card.save!
      end
    end

    def display_gift_card_total
      Spree::Money.new(gift_card_total, currency: currency)
    end

    def total_minus_gift_cards
      total - gift_card_total
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
      result = Spree::Carts::RemoveOutOfStockItems.call(order: self)
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

    def currency_must_be_supported_by_store
      return if currency.blank? || store.blank?

      supported_codes = store.supported_currencies_list.map(&:iso_code)
      unless supported_codes.include?(currency)
        errors.add(:currency, Spree.t(:currency_not_supported_by_store))
      end
    end

    def ensure_market_presence
      self.market ||= Spree::Current.market || store&.default_market
    end

    # When currency changes, auto-resolve the matching market (mirrors Order).
    def resolve_market_from_currency
      return unless store&.markets&.exists?
      return if market&.currency == currency

      resolved = store.markets.find_by(currency: currency)
      self.market = resolved if resolved
    end

    def ensure_channel_presence
      return if channel_id.present?

      self.channel = store&.default_channel
    end
  end
end
