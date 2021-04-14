module Spree
  module Api
    module V2
      module DisplayMoneyHelper
        extend ActiveSupport::Concern

        class_methods do
          def find_price(product_or_variant, currency)
            product_or_variant.price_in(currency)
          end

          def price(product_or_variant, currency)
            price = find_price(product_or_variant, currency)
            return nil if price.new_record?

            format('%.2f', price.amount)
          end

          def display_price(product_or_variant, currency)
            price = find_price(product_or_variant, currency)
            return nil if price.new_record?

            Spree::Money.new(price.amount, currency: currency).to_s
          end

          def compare_at_price(product_or_variant, currency)
            price = find_price(product_or_variant, currency)
            return nil if price.new_record? || price.compare_at_amount.blank?

            format('%.2f', price.compare_at_amount)
          end

          def display_compare_at_price(product_or_variant, currency)
            price = find_price(product_or_variant, currency)
            return nil if price.new_record? || price.compare_at_amount.blank?

            Spree::Money.new(price.compare_at_amount, currency: currency).to_s
          end
        end
      end
    end
  end
end
