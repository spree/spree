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

        line_item.errors[:quantity] << Spree.t(
          :selected_quantity_not_available,
          item: display_name.inspect
        )
      end

      private

      def item_available?(line_item, quantity)
        Stock::Quantifier.new(line_item.variant).can_supply?(quantity)
      end
    end
  end
end
