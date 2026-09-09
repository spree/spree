module Spree
  class LineItem < Spree.base_class
    has_prefix_id :li  # Spree-specific: line item

    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    attribute :quantity, :integer, default: 1

    before_validation :ensure_valid_quantity

    with_options inverse_of: :line_items do
      belongs_to :order, class_name: 'Spree::Order', touch: true, optional: true
      belongs_to :cart, class_name: 'Spree::Cart', touch: true, optional: true
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end
    belongs_to :tax_category, -> { with_deleted }, class_name: 'Spree::TaxCategory', optional: true
    belongs_to :price_list, class_name: 'Spree::PriceList', optional: true
    # Snapshotted from the variant when the line is added — see copy_seller.
    # Nil is the operator's own first-party item.
    belongs_to :seller, class_name: 'Spree::Seller', optional: true

    has_one :product, -> { with_deleted }, class_name: 'Spree::Product', through: :variant

    has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy, inverse_of: :line_item
    has_many :discounts, class_name: 'Spree::Discount', dependent: :destroy, inverse_of: :line_item
    has_many :fees, class_name: 'Spree::Fee', dependent: :destroy, inverse_of: :line_item
    has_many :fulfillment_items, class_name: 'Spree::FulfillmentItem', inverse_of: :line_item, dependent: :destroy
    has_many :fulfillments, through: :fulfillment_items, source: :fulfillment
    has_many :inventory_units, class_name: 'Spree::FulfillmentItem', inverse_of: :line_item, deprecated: true
    has_many :shipments, through: :fulfillment_items, source: :fulfillment, deprecated: true
    has_many :digital_links, dependent: :destroy
    has_many :stock_reservations, class_name: 'Spree::StockReservation', inverse_of: :line_item, dependent: :destroy

    # Set by Spree::Carts::PriceItems when a workflow has already resolved
    # this line's price outside the transaction. The quantity-change callback
    # then stands down rather than asking the provider a second time from
    # inside the save — which is the network-call-in-transaction the workflow
    # split exists to prevent, and would overwrite the fresher answer.
    attr_accessor :price_resolved

    before_validation :copy_price
    before_validation :copy_tax_category
    before_validation :copy_seller

    validate :exactly_one_owner

    DB_INTEGER_MAX = (2**31) - 1

    # The +price_source+ value marking a negotiated (admin-set) unit price.
    # Reserved: no pricing provider may register it as its key — see
    # Spree::PricingProvider.verify_registry!.
    MANUAL_PRICE_SOURCE = Spree::PricingProvider::MANUAL_PRICE_SOURCE

    # numericality: :less_than_or_equal_to validation is due to the restriction at the database level
    #   https://github.com/spree/spree/issues/2695#issuecomment-143314161
    validates :quantity, numericality: {
      in: 0..DB_INTEGER_MAX,
      only_integer: true, message: Spree.t('validation.must_be_int')
    }

    validates :price, numericality: true

    validates_with Spree::Stock::AvailabilityValidator, if: -> { variant.present? }
    validate :ensure_proper_currency, if: -> { owner.present? }

    # Order-side only: a cart's fulfillment items are built by the Stock
    # Coordinator and copied at completion, so `owner` would be wrong here.
    # Removing an item from a placed order must drain its units and restock —
    # `removing: true` keeps verify from re-adding units mid-destroy.
    before_destroy :verify_order_inventory_before_destroy, if: -> { order.present? }

    after_save :update_inventory
    after_save :update_adjustments

    # Set on copies whose tax is already known — the completion copy carries the
    # cart's tax rows over verbatim, so re-estimating would discard the answer
    # and, with an external engine, spend a remote call per line item.
    attr_accessor :skip_tax_estimation

    after_create :update_tax_charge, unless: :skip_tax_estimation

    delegate :sku, :should_track_inventory?, :product, :options_text, :slug, :product_id, :dimensions_unit, :weight_unit, :option_values, to: :variant
    delegate :name, :description, :brand, :category, to: :product

    # Returns the thumbnail image for this line item
    # Prefers variant primary media, falls back to product primary media
    # @return [Spree::Media, nil]
    def thumbnail
      variant.primary_media || product.primary_media
    end
    delegate :digital?, :can_supply?, to: :variant
    # A line item's store is its owner's — an order's or a cart's, whichever it
    # belongs to.
    delegate :store, to: :owner

    scope :with_digital_assets, -> { joins(:variant).merge(Spree::Variant.with_digital_assets) }

    # Pins inventory-unit placement to a specific fulfillment when set
    # (admin add-to-this-fulfillment flows).
    attr_accessor :target_fulfillment

    # @deprecated Use {#target_fulfillment}; removed in 6.1.
    def target_shipment
      Spree::Deprecation.warn('Spree::LineItem#target_shipment is deprecated and will be removed in Spree 6.1. Use #target_fulfillment instead.')
      target_fulfillment
    end

    # @deprecated Use {#target_fulfillment=}; removed in 6.1.
    def target_shipment=(value)
      Spree::Deprecation.warn('Spree::LineItem#target_shipment= is deprecated and will be removed in Spree 6.1. Use #target_fulfillment= instead.')
      self.target_fulfillment = value
    end

    self.whitelisted_ransackable_associations = %w[variant order tax_category]
    self.whitelisted_ransackable_attributes = %w[variant_id order_id tax_category_id quantity
                                                 price cost_price cost_currency adjustment_total
                                                 additional_tax_total discount_total included_tax_total
                                                 pre_tax_amount taxable_adjustment_total
                                                 non_taxable_adjustment_total]

    # The exactly-one owner of this line item — the cart during checkout, the
    # order after completion. New code must read +owner+, never assume +order+.
    #
    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end

    def copy_price
      if variant
        # Local catalog only: this runs inside a save, and the workflows have
        # already priced the line through the provider before the transaction
        # opened. Reaching a provider from a validation callback would put a
        # network call inside every line-item save.
        copy_catalog_price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = owner.currency if currency.nil? && owner
      end
    end

    # Assigns the current price without saving — the caller is expected to.
    # {#recalculate_price} persists instead.
    #
    # Restatement for a tax-inclusive market happens inside
    # {Spree::Carts::PriceItems}: an address-less cart still has a taxing
    # country (its market's own), and without it a cross-border cart is taxed
    # for the destination at a price quoted for home, leaving the merchant to
    # absorb the difference.
    # persist: false — runs mid-build and from callers that save the record
    # themselves.
    def update_price
      reprice(persist: false)
    end

    # Assigns the price the local catalog gives for this line, with no pricing
    # provider consulted — the fallback for a line built outside a workflow
    # (seeds, console, an extension) that would otherwise be saved with no
    # price at all. Assigns without saving; the caller is mid-save.
    #
    # @return [void]
    def copy_catalog_price
      context = Spree::Pricing::Context.from_order(variant, owner, quantity: quantity)
      price_record = Spree::PricingProvider::Internal.new.price_for(context)
      return if price_record.blank?

      # Through the same writer every resolved price goes through, so the
      # tax-inclusive restatement inputs are stated once.
      Spree::Carts::PriceItems.apply([[self, price_record]], persist: false)
    end

    def copy_tax_category
      self.tax_category = variant.tax_category if variant
    end

    # Reads the seller off the variant, which resolves it — its own when the
    # variant carries one, otherwise the product's.
    #
    # Only filled while the line is still being chosen — a cart, or an admin
    # draft that has not been placed. Once the order is placed the line records
    # who sold it, and nothing about the catalog changing hands afterwards may
    # rewrite that, including a first-party line whose nil is just as much a
    # record as a seller's id.
    #
    # Keyed on the order being placed rather than on the line being persisted:
    # a draft order's lines are persisted too, and they must keep following
    # their product until the order is actually placed.
    def copy_seller
      return if variant.blank?
      return if order&.placed?

      self.seller_id = variant.resolved_seller_id
    end

    extend DisplayMoney
    money_methods :amount, :subtotal, :discounted_amount, :final_amount, :total, :price, :discounted_price,
                  :adjustment_total, :additional_tax_total, :discount_total, :included_tax_total,
                  :pre_tax_amount, :delivery_cost, :tax_total, :compare_at_amount

    alias single_money display_price
    alias single_display_amount display_price

    # Standardized column name (renamed in 6.0); the legacy reader stays one
    # release.
    alias_attribute :promo_total, :discount_total
    alias display_promo_total display_discount_total

    def discounted_price
      return price if quantity.zero?

      price - (discount_total.abs / quantity)
    end

    # Returns the amount (price * quantity) of the line item
    #
    # @return [BigDecimal]
    def amount
      price * quantity
    end

    # Returns the compare at amount (compare at price * quantity) of the line item
    #
    # @return [BigDecimal]
    def compare_at_amount
      (variant.compare_at_amount_in(currency) || 0) * quantity
    end

    alias subtotal amount

    # Returns the taxable amount (amount + taxable adjustment total) of the line item
    #
    # @return [BigDecimal]
    def taxable_amount
      amount + taxable_adjustment_total
    end

    # returns the total tax amount
    #
    # @return [BigDecimal]
    def tax_total
      included_tax_total + additional_tax_total
    end

    alias discounted_money display_discounted_amount
    alias discounted_amount taxable_amount

    # Returns the amount this line item is taxed on. Whole-order promotions
    # are distributed to line-item Discount rows at application time, so the
    # discounted amount already carries the line's share. Never negative.
    #
    # @return [BigDecimal]
    def taxable_basis
      [taxable_amount, BigDecimal(0)].max
    end

    # Returns the final amount of the line item
    #
    # @return [BigDecimal]
    def final_amount
      amount + adjustment_total
    end

    # Returns the weight of the line item
    #
    # @return [BigDecimal]
    def item_weight
      variant.weight * quantity
    end

    alias total final_amount
    alias money display_total

    # Returns true if the line item has sufficient stock
    #
    # The owner's own active stock reservations are excluded from the
    # availability check — a customer's own checkout hold must not make
    # their own line item look out of stock.
    #
    # @return [Boolean]
    def sufficient_stock?
      Spree::Stock::Quantifier.new(variant, excluded_order: owner).can_supply?(quantity)
    end

    # Returns true if the line item has insufficient stock
    #
    # @return [Boolean]
    def insufficient_stock?
      !sufficient_stock?
    end

    # returns true if any of the inventory units are shipped
    #
    # @return [Boolean]
    def any_shipped?
      fulfillment_items.any?(&:shipped?)
    end

    # returns true if all of the inventory units are shipped
    #
    # @return [Boolean]
    def fully_shipped?
      fulfillment_items.all?(&:shipped?)
    end

    # This line item's share of its fulfillments' delivery cost, split
    # proportionally by unit count.
    #
    # @return [BigDecimal]
    def delivery_cost
      # distinct: the has_many :through yields one row per fulfillment item,
      # so a fulfillment holding several of this line item's units would
      # otherwise be counted once per unit.
      fulfillments.distinct.sum do |fulfillment|
        # next, never return — a return here would abandon the whole sum, so
        # one skippable fulfillment would zero out every other one.
        next BigDecimal('0') if fulfillment.canceled? || fulfillment.cost.zero?

        units = fulfillment.fulfillment_items
        next BigDecimal('0') if units.empty?

        line_item_units = units.count { |unit| unit.line_item_id == id }
        next BigDecimal('0') if line_item_units.zero?

        fulfillment.cost * (line_item_units.to_d / units.count)
      end
    end

    # @deprecated Use {#delivery_cost}; removed in 6.1.
    def shipping_cost
      Spree::Deprecation.warn('Spree::LineItem#shipping_cost is deprecated and will be removed in Spree 6.1. Use #delivery_cost instead.')
      delivery_cost
    end

    # @deprecated Use {#display_delivery_cost}; removed in 6.1.
    def display_shipping_cost
      Spree::Deprecation.warn('Spree::LineItem#display_shipping_cost is deprecated and will be removed in Spree 6.1. Use #display_delivery_cost instead.')
      display_delivery_cost
    end

    def options=(options = {})
      return unless options.present?

      opts = options.dup # we will be deleting from the hash, so leave the caller's copy intact

      currency = opts.delete(:currency) || owner&.currency

      update_price_from_modifier(currency, opts)
      assign_attributes opts
    end

    # Returns the maximum quantity that can be added to the line item
    #
    # @return [Integer]
    def maximum_quantity
      @maximum_quantity ||= variant.backorderable? ? DB_INTEGER_MAX : variant.total_on_hand
    end

    # Returns true if the line item variant has digital assets
    #
    # @return [Boolean]
    def with_digital_assets?
      variant.with_digital_assets?
    end

    # Whether this line carries a negotiated price set by staff. A manual
    # price is never overwritten by repricing — only the explicit revert
    # (+price: nil+ through the admin item update) clears it.
    #
    # @return [Boolean]
    def manual_price?
      price_source == MANUAL_PRICE_SOURCE
    end

    # Recalculates and persists the price based on the current quantity and
    # pricing context — volume breaks, price list rules, contract pricing.
    #
    # A thin delegate to {Spree::Carts::PriceItems}, which is where a store's
    # pricing provider is consulted. Prefer calling that service directly for
    # anything touching more than one line: it asks the provider once for the
    # batch, while this asks once per item.
    #
    # @return [void]
    def recalculate_price
      reprice(persist: true)
    end

    private

    def reprice(persist:)
      return if owner.blank?

      result = Spree::Carts::PriceItems.new.call(cart: owner, line_items: [self])
      Spree::Carts::PriceItems.apply(result.value, persist: persist) if result.success?
    end

    def ensure_valid_quantity
      self.quantity = 0 if quantity.nil? || quantity < 0
    end

    def update_price_from_modifier(currency, opts)
      if currency
        self.currency = currency
        # variant.price_in(currency).amount can be nil if
        # there's no price for this currency
        self.price = (variant.price_in(currency).amount || 0) +
          variant.price_modifier_amount_in(currency, opts)
      else
        self.price = (variant.price_in(self.currency).amount || 0) +
          variant.price_modifier_amount(opts)
      end
    end

    # Order-side only (see before_destroy above); OrderInventory#verify
    # itself returns early unless the order is completed.
    #
    # No digitality gate: digital items get fulfillment items too (the
    # Digital provider issues one link per unit), and stock-limited digital
    # items — licences, seats, tickets — must decrement like anything else.
    # Tracking is decided per variant by should_track_inventory?.
    def update_inventory
      if (saved_changes? || target_fulfillment.present?) && order.present?
        verify_order_inventory
      end
    end

    def verify_order_inventory
      Spree::OrderInventory.new(order, self).verify(target_fulfillment, is_updated: true)
    end

    def verify_order_inventory_before_destroy
      Spree::OrderInventory.new(order, self).verify(target_fulfillment, removing: true)
    end

    def update_adjustments
      # Typed rows (discounts + tax) are rebuilt by the order-level
      # recalculation, which every cart/checkout flow runs after the save —
      # recalculating from here would cache the owner's associations
      # mid-mutation and hide later changes from that run.
      # One-shot: the mark covers the save that is happening now, not the
      # instance forever, or a later quantity change on the same object would
      # never re-price.
      already_priced = price_resolved
      self.price_resolved = false

      if saved_change_to_quantity? && owner&.persisted? && !owner.completed?
        recalculate_price if should_update_price? && !previously_new_record? && !already_priced
      end
    end

    # Returns true if the price should be updated when quantity changes
    # Override this method to customize when prices should be recalculated
    # By default, prices are not updated after an order is completed, and a
    # negotiated (manual) price is never re-derived by a quantity change.
    # @return [Boolean]
    def should_update_price?
      !owner.completed? && !manual_price?
    end

    def update_tax_charge
      return unless owner

      owner.tax_provider.estimate(owner, [self], **owner.tax_estimate_inputs)
    end

    def ensure_proper_currency
      unless currency == owner.currency
        errors.add(:currency, :must_match_order_currency)
      end
    end

    def exactly_one_owner
      errors.add(:base, :exactly_one_of_cart_or_order, message: Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
