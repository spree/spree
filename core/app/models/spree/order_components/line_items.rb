require 'active_support/core_ext/enumerable'

module Spree
  module OrderComponents
    module LineItems
      def self.included(base)
        base.class_eval do
          attr_accessible :line_items, :line_items_attributes

          has_many :line_items, :dependent => :destroy

          accepts_nested_attributes_for :line_items
        end
      end

      def products
        line_items.map { |li| li.variant.product }
      end

      def contains?(variant)
        find_line_item_by_variant(variant).present?
      end

      def quantity_of(variant)
        line_item = find_line_item_by_variant(variant)
        line_item ? line_item.quantity : 0
      end

      def find_line_item_by_variant(variant)
        line_items.detect { |line_item| line_item.variant_id == variant.id }
      end

      # For compatibility with Calculator::PriceSack
      def amount
        line_items.sum(&:amount)
      end

      def add_variant(variant, quantity = 1)
        current_item = find_line_item_by_variant(variant)
        if current_item
          current_item.quantity += quantity
          current_item.save
        else
          current_item = LineItem.new(:quantity => quantity)
          current_item.variant = variant
          current_item.price   = variant.price
          self.line_items << current_item
        end

        self.reload
        current_item
      end
    end
  end
end
