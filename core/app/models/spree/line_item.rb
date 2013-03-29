module Spree
  class LineItem < ActiveRecord::Base
    before_validation :adjust_quantity
    belongs_to :order
    belongs_to :variant, :class_name => "Spree::Variant"

    has_one :product, :through => :variant
    has_many :adjustments, :as => :adjustable, :dependent => :destroy

    before_validation :copy_price

    validates :variant, :presence => true
    validates :quantity, :numericality => { :only_integer => true, :message => I18n.t('validation.must_be_int'), :greater_than => -1 }
    validates :price, :numericality => true
    validate :stock_availability

    attr_accessible :quantity, :variant_id

    after_save :update_order
    after_destroy :update_order

    def copy_price
      if variant
        self.price = variant.price if price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def increment_quantity
      self.quantity += 1
    end

    def decrement_quantity
      self.quantity -= 1
    end

    def amount
      price * quantity
    end
    alias total amount

    def single_money
      Spree::Money.new(price, { :currency => currency })
    end
    alias single_display_amount single_money

    def money
      Spree::Money.new(amount, { :currency => currency })
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

    private
    def update_order
      # update the order totals, etc.
      order.create_tax_charge!
      order.update!
    end

    # Validation
    def stock_availability
      return if sufficient_stock?
      errors.add(:quantity, I18n.t('validation.exceeds_available_stock'))
    end
  end
end
