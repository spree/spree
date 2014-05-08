module Spree
  module Stock
    class AvailabilityValidator < ActiveModel::Validator
      def validate(line_item)
        if shipment = line_item.target_shipment
          units = shipment.inventory_units_for(line_item.variant)
          return if units.count > line_item.quantity
          quantity = line_item.quantity - units.count
        else
          quantity = line_item.quantity
        end

        quantifier = Stock::Quantifier.new(line_item.variant)

        unless quantifier.can_supply? quantity
          variant = line_item.variant
          display_name = %Q{#{variant.name}}
          display_name += %Q{ (#{variant.options_text})} unless variant.options_text.blank?

          line_item.errors[:quantity] << Spree.t(:selected_quantity_not_available, :scope => :order_populator, :item => display_name.inspect)
        end
      end
    end
  end
end
