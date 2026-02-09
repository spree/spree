module Spree
  module Stock
    class AvailabilityValidator < ActiveModel::Validator
      def validate(line_item)
        unit_count = line_item.inventory_units.reject(&:pending?).sum(&:quantity)
        return if unit_count >= line_item.quantity

        quantity = line_item.quantity - unit_count
        return if quantity.zero?

        return if item_available?(line_item, quantity)

        variant = line_item.variant
        display_name = variant.name.to_s
        display_name += " (#{variant.options_text})" unless variant.options_text.blank?

        if variant.available?
          line_item.errors.add(:quantity,
                               :selected_quantity_not_available,
                               message: Spree.t(:selected_quantity_not_available, item: display_name.inspect))
        else
          line_item.errors.add(:base,
                               :only_active_products_can_be_added_to_cart,
                               message: Spree.t(:only_active_products_can_be_added_to_cart))
        end
      end

      private

      def item_available?(line_item, quantity)
        Spree::Stock::Quantifier.new(line_item.variant).can_supply?(quantity)
      end
    end
  end
end
