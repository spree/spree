module Spree
  class LineItem < ActiveRecord::Base
    before_validation :adjust_quantity
    belongs_to :order, class_name: "Spree::Order"
    belongs_to :variant, class_name: "Spree::Variant"

    has_one :product, through: :variant
    has_many :adjustments, as: :adjustable, dependent: :destroy

    before_validation :copy_price

    validates :variant, presence: true
    validates :quantity, numericality: {
      only_integer: true,
      greater_than: -1,
      message: Spree.t('validation.must_be_int')
    }
    validates :price, numericality: true
    validates_with Stock::AvailabilityValidator

    attr_accessible :quantity, :variant_id

    before_save :update_inventory

    after_save :update_order
    after_destroy :update_order

    attr_accessor :target_shipment

    def copy_price
      if variant
        self.price = variant.price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def increment_quantity
      ActiveSupport::Deprecation.warn("[SPREE] Spree::LineItem#increment_quantity will be deprecated in Spree 2.1, please use quantity.increment! instead.")
      self.quantity.increment!
    end

    def decrement_quantity
      ActiveSupport::Deprecation.warn("[SPREE] Spree::LineItem#decrement_quantity will be deprecated in Spree 2.1, please use quantity.decrement! instead.")
      self.quantity.decrement!
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

    private
      def update_inventory
        Spree::OrderInventory.new(self.order).verify(self, target_shipment)
      end

      def update_order
        # update the order totals, etc.
        order.create_tax_charge!
        order.update!
      end
  end
end

