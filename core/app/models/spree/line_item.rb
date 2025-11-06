module Spree
  class LineItem < Spree.base_class
    include Spree::Metafields
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    attribute :quantity, :integer, default: 1

    before_validation :ensure_valid_quantity

    with_options inverse_of: :line_items do
      belongs_to :order, class_name: 'Spree::Order', touch: true
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end
    belongs_to :tax_category, -> { with_deleted }, class_name: 'Spree::TaxCategory'

    has_one :product, -> { with_deleted }, class_name: 'Spree::Product', through: :variant

    has_many :adjustments, as: :adjustable, dependent: :destroy
    has_many :inventory_units, class_name: 'Spree::InventoryUnit', inverse_of: :line_item, dependent: :destroy
    has_many :shipments, through: :inventory_units, source: :shipment
    has_many :digital_links, dependent: :destroy

    before_validation :copy_price
    before_validation :copy_tax_category

    validates :variant, :order, presence: true

    # numericality: :less_than_or_equal_to validation is due to the restriction at the database level
    #   https://github.com/spree/spree/issues/2695#issuecomment-143314161
    validates :quantity, numericality: {
      in: 0..DatabaseTypeUtilities.maximum_value_for(:integer),
      only_integer: true, message: Spree.t('validation.must_be_int')
    }

    validates :price, numericality: true

    validates_with Spree::Stock::AvailabilityValidator, if: -> { variant.present? }
    validate :ensure_proper_currency, if: -> { order.present? }

    before_destroy :verify_order_inventory_before_destroy, if: -> { order.has_checkout_step?('delivery') }

    after_save :update_inventory
    after_save :update_adjustments

    after_create :update_tax_charge

    delegate :name, :description, :sku, :should_track_inventory?, :product, :options_text, :slug, :product_id, :dimensions_unit, :weight_unit, to: :variant
    delegate :brand, :category, to: :product
    delegate :tax_zone, to: :order
    delegate :digital?, to: :variant

    scope :with_digital_assets, -> { joins(:variant).merge(Spree::Variant.with_digital_assets) }

    attr_accessor :target_shipment

    self.whitelisted_ransackable_associations = %w[variant order tax_category]
    self.whitelisted_ransackable_attributes = %w[variant_id order_id tax_category_id quantity
                                                 price cost_price cost_currency adjustment_total
                                                 additional_tax_total promo_total included_tax_total
                                                 pre_tax_amount taxable_adjustment_total
                                                 non_taxable_adjustment_total]

    def copy_price
      if variant
        update_price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = order.currency if currency.nil?
      end
    end

    def update_price
      currency_price = variant.price_in(order.currency)

      self.price = currency_price.price_including_vat_for(tax_zone: tax_zone) if currency_price.present?
    end

    def copy_tax_category
      self.tax_category = variant.tax_category if variant
    end

    extend DisplayMoney
    money_methods :amount, :subtotal, :discounted_amount, :final_amount, :total, :price, :discounted_price,
                  :adjustment_total, :additional_tax_total, :promo_total, :included_tax_total,
                  :pre_tax_amount, :shipping_cost, :tax_total, :compare_at_amount

    alias single_money display_price
    alias single_display_amount display_price

    def discounted_price
      return price if quantity.zero?

      price - (promo_total.abs / quantity)
    end

    def amount
      price * quantity
    end

    def compare_at_amount
      (variant.compare_at_amount_in(currency) || 0) * quantity
    end

    alias subtotal amount

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

    def sufficient_stock?
      Spree::Stock::Quantifier.new(variant).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    # returns true if any of the inventory units are shipped
    #
    # @return [Boolean]
    def any_shipped?
      inventory_units.any?(&:shipped?)
    end

    # returns true if all of the inventory units are shipped
    #
    # @return [Boolean]
    def fully_shipped?
      inventory_units.all?(&:shipped?)
    end

    # Returns the shipping cost for the line item
    #
    # @return [BigDecimal]
    def shipping_cost
      shipments.sum do |shipment|
        # Skip cancelled shipments
        return BigDecimal('0') if shipment.canceled?

        # Get all inventory units in this shipment for this line item
        line_item_units = shipment.inventory_units.where(line_item_id: id).count

        # Get total inventory units in this shipment
        total_units = shipment.inventory_units.count

        # Calculate proportional shipping cost
        return BigDecimal('0') if total_units.zero? || line_item_units.zero? || shipment.cost.zero?

        shipment.cost * (line_item_units.to_d / total_units)
      end
    end

    def options=(options = {})
      return unless options.present?

      opts = options.dup # we will be deleting from the hash, so leave the caller's copy intact

      currency = opts.delete(:currency) || order.try(:currency)

      update_price_from_modifier(currency, opts)
      assign_attributes opts
    end

    # Returns the maximum quantity that can be added to the line item
    #
    # @return [Integer]
    def maximum_quantity
      @maximum_quantity ||= variant.backorderable? ? Spree::DatabaseTypeUtilities.maximum_value_for(:integer) : variant.total_on_hand
    end

    def with_digital_assets?
      variant.with_digital_assets?
    end

    private

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
        self.price = variant.price +
          variant.price_modifier_amount(opts)
      end
    end

    def update_inventory
      if (saved_changes? || target_shipment.present?) && order.has_checkout_step?('delivery')
        verify_order_inventory
      end
    end

    def verify_order_inventory
      Spree::OrderInventory.new(order, self).verify(target_shipment, is_updated: true)
    end

    def verify_order_inventory_before_destroy
      Spree::OrderInventory.new(order, self).verify(target_shipment)
    end

    def update_adjustments
      if saved_change_to_quantity?
        recalculate_adjustments
        update_tax_charge # Called to ensure pre_tax_amount is updated.
      end
    end

    def recalculate_adjustments
      Spree::Adjustable::AdjustmentsUpdater.update(self)
    end

    def update_tax_charge
      Spree::TaxRate.adjust(order, [self])
    end

    def ensure_proper_currency
      unless currency == order.currency
        errors.add(:currency, :must_match_order_currency)
      end
    end
  end
end
