require_dependency 'spree/shipping_calculator'

module Spree
  module Calculator::Shipping
    class FlexiRate < ShippingCalculator
      preference :first_item,      :decimal, default: 0.0
      preference :additional_item, :decimal, default: 0.0
      preference :max_items,       :integer, default: 0
      preference :currency,        :string,  default: ->{ Spree::Config[:currency] }

      def self.description
        Spree.t(:shipping_flexible_rate)
      end

      def compute_package(package)
        compute_from_quantity(package.contents.sum(&:quantity))
      end

      def compute_from_quantity(quantity)
        sum = 0
        max = self.preferred_max_items.to_i
        quantity.times do |i|
          # check max value to avoid divide by 0 errors
          if (max == 0 && i == 0) || (max > 0) && (i % max == 0)
            sum += self.preferred_first_item.to_f
          else
            sum += self.preferred_additional_item.to_f
          end
        end

        sum
      end
    end
  end
end
