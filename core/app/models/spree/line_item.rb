module Spree
  class LineItem < Spree::Base
    before_validation :ensure_valid_quantity

    with_options inverse_of: :line_items do
      belongs_to :order, class_name: 'Spree::Order', touch: true
      belongs_to :variant, class_name: 'Spree::Variant'
    end
    belongs_to :tax_category, class_name: 'Spree::TaxCategory'

    has_one :product, through: :variant

    has_many :adjustments, as: :adjustable, dependent: :destroy
    has_many :inventory_units, inverse_of: :line_item

    before_validation :copy_price
    before_validation :copy_tax_category

    validates :variant, :order, presence: true

    # numericality: :less_than_or_equal_to validation is due to the restriction at the database level
    #   https://github.com/spree/spree/issues/2695#issuecomment-143314161
    validates :quantity, numericality: {
      less_than_or_equal_to: DatabaseTypeUtilities.maximum_value_for(:integer),
      only_integer: true, message: Spree.t('validation.must_be_int')
    }

    validates :price, numericality: true

    validates_with Spree::Stock::AvailabilityValidator
    validate :ensure_proper_currency, if: -> { order.present? }

    before_destroy :verify_order_inventory_before_destroy, if: -> { order.has_checkout_step?('delivery') }

    before_destroy :destroy_inventory_units

    after_save :update_inventory
    after_save :update_adjustments

    after_create :update_tax_charge

    delegate :name, :description, :sku, :should_track_inventory?, :product, :options_text, :slug, to: :variant
    delegate :brand, :category, to: :product
    delegate :tax_zone, to: :order

    attr_accessor :target_shipment

    self.whitelisted_ransackable_associations = ['variant']
    self.whitelisted_ransackable_attributes = ['variant_id']

    def copy_price
      if variant
        update_price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def update_price
      self.price = variant.price_including_vat_for(tax_zone: tax_zone)
    end

    def copy_tax_category
      self.tax_category = variant.tax_category if variant
    end

    extend DisplayMoney
    money_methods :amount, :subtotal, :discounted_amount, :final_amount, :total, :price,
                  :adjustment_total, :additional_tax_total, :promo_total, :included_tax_total

    alias single_money display_price
    alias single_display_amount display_price

    def amount
      price * quantity
    end

    alias subtotal amount

    def taxable_amount
      amount + taxable_adjustment_total
    end

    alias discounted_money display_discounted_amount
    alias discounted_amount taxable_amount

    def final_amount
      amount + adjustment_total
    end

    alias total final_amount
    alias money display_total

    def sufficient_stock?
      Spree::Stock::Quantifier.new(variant).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    def options=(options = {})
      return unless options.present?

      opts = options.dup # we will be deleting from the hash, so leave the caller's copy intact

      currency = opts.delete(:currency) || order.try(:currency)

      update_price_from_modifier(currency, opts)
      assign_attributes opts
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
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

    def destroy_inventory_units
      throw(:abort) unless inventory_units.destroy_all
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
