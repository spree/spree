module Spree
  class LineItem < ActiveRecord::Base
    before_validation :adjust_quantity
    belongs_to :order, class_name: "Spree::Order"
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
    alias total amount

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

    # Tells us if there if the specified promotion is already associated with the line item
    # regardless of whether or not its currently eligible. Useful because generally
    # you would only want a promotion action to apply to order no more than once.
    #
    # Receives an adjustment +source+ (here a PromotionAction object) and tells
    # if the order has adjustments from that already
    def promotion_credit_exists?(source)
      !!adjustments.promotion.where(:source_id => source.id).exists?
    end

    private
      def update_inventory
        if changed?
          Spree::OrderInventory.new(self.order).verify(self, target_shipment)
        end
      end

      # Picks one (and only one) promotion to be eligible for this order
      # This promotion provides the most discount, and if two promotions
      # have the same amount, then it will pick the latest one.
      def choose_best_promotion_adjustment
        if best_promotion_adjustment = self.adjustments.promotion.eligible.reorder("amount ASC, created_at DESC").first
          other_promotions = self.adjustments.promotion.where("id NOT IN (?)", best_promotion_adjustment.id)
          other_promotions.update_all(:eligible => false)
        end
      end

      def update_adjustments
        adjustment_total = adjustments.map(&:update!)
        choose_best_promotion_adjustment
        self.update_column(:adjustment_total, adjustment_total)
        OrderUpdater.new(order).update_adjustments
      end
  end
end

