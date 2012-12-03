module Spree
  class LineItem < ActiveRecord::Base
    before_validation :adjust_quantity
    belongs_to :order
    belongs_to :variant

    has_one :product, :through => :variant
    has_many :adjustments, :as => :adjustable, :dependent => :destroy

    before_validation :copy_price

    validates :variant, :presence => true
    validates :quantity, :numericality => { :only_integer => true, :message => I18n.t('validation.must_be_int'), :greater_than => -1 }
    validates :price, :numericality => true
    validate :stock_availability
    validate :quantity_no_less_than_shipped

    attr_accessible :quantity, :variant_id

    before_save :update_inventory
    before_destroy :ensure_not_shipped, :remove_inventory

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
      return true if Spree::Config[:allow_backorders]
      if new_record? || !order.completed?
        variant.on_hand >= quantity
      else
        variant.on_hand >= (quantity - self.changed_attributes['quantity'].to_i)
      end
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    private
      def update_inventory
        return true unless order.completed?

        if new_record?
          InventoryUnit.increase(order, variant, quantity)
        elsif old_quantity = self.changed_attributes['quantity']
          if old_quantity < quantity
            InventoryUnit.increase(order, variant, (quantity - old_quantity))
          elsif old_quantity > quantity
            InventoryUnit.decrease(order, variant, (old_quantity - quantity))
          end
        end
      end

      def remove_inventory
        return true unless order.completed?

        InventoryUnit.decrease(order, variant, quantity)
      end

      def update_order
        # update the order totals, etc.
        order.create_tax_charge!
        order.update!
      end

      def ensure_not_shipped
        if order.try(:inventory_units).to_a.any?{ |unit| unit.variant_id == variant_id && unit.shipped? }
          errors.add :base, I18n.t('validation.cannot_destory_line_item_as_inventory_units_have_shipped')
          return false
        end
      end

      # Validation
      def stock_availability
        return if sufficient_stock?
        errors.add(:quantity, I18n.t('validation.cannot_be_greater_than_available_stock'))
      end

      def quantity_no_less_than_shipped
        already_shipped = order.shipments.reduce(0) { |acc, s| acc + s.inventory_units.shipped.where(:variant_id => variant_id).count }
        unless quantity >= already_shipped
          errors.add(:quantity, I18n.t('validation.cannot_be_less_than_shipped_units'))
        end
      end
  end
end
