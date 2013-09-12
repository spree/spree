module Spree
  class LineItem < ActiveRecord::Base
    before_validation :adjust_quantity
    belongs_to :order, class_name: "Spree::Order", :inverse_of => :line_items
    belongs_to :variant, class_name: "Spree::Variant"
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    has_one :product, through: :variant
    has_many :adjustments, as: :adjustable, dependent: :destroy

    before_validation :copy_price
    before_validation :copy_tax_category

    validates :variant, presence: true
    validates :quantity, numericality: {
      only_integer: true,
      greater_than: -1,
      message: Spree.t('validation.must_be_int')
    }
    validates :price, numericality: true
    validates_with Stock::AvailabilityValidator

    before_save :update_inventory
    after_save :update_adjustments

    attr_accessor :target_shipment

    def copy_price
      if variant
        self.price = variant.price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def copy_tax_category
      if variant
        self.tax_category = variant.product.tax_category
      end
    end

    def amount
      price * quantity
    end
    alias subtotal amount

    def final_amount
      amount + adjustment_total.to_f
    end
    alias total final_amount

    def single_money
      Spree::Money.new(price, { currency: currency })
    end
    alias single_display_amount single_money

    def money
      Spree::Money.new(amount, { currency: currency })
    end
    alias display_total money
    alias display_amount money

    def adjust_quantity
      self.quantity = 0 if quantity.nil? || quantity < 0
    end

    def sufficient_stock?
      Stock::Quantifier.new(variant_id).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    def assign_stock_changes_to=(shipment)
      @preferred_shipment = shipment
    end

    # Remove product default_scope `deleted_at: nil`
    def product
      variant.product
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    private
      def update_inventory
        Spree::OrderInventory.new(self.order).verify(self, target_shipment)
      end

      def update_adjustments
        if quantity_changed?
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Spree::ItemAdjustments.new(self).update
      end
  end
end

