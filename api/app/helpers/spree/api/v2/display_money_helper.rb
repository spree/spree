module Spree
  module Api
    module V2
      module DisplayMoneyHelper
        extend ActiveSupport::Concern

        class_methods do
          def find_price(product_or_variant, currency, context_options = {})
            variant = product_or_variant.is_a?(Spree::Product) ? product_or_variant.default_variant : product_or_variant

            if context_options.present?
              context = build_pricing_context(variant, currency, context_options)
              variant.price_for(context)
            else
              variant.price_in(currency)
            end
          end

          def price(product_or_variant, currency, context_options = {})
            price = find_price(product_or_variant, currency, context_options)
            return nil if price.new_record?

            price.amount
          end

          def display_price(product_or_variant, currency, context_options = {})
            price = find_price(product_or_variant, currency, context_options)
            return nil if price.new_record?

            Spree::Money.new(price.amount, currency: currency).to_s
          end

          def compare_at_price(product_or_variant, currency, context_options = {})
            price = find_price(product_or_variant, currency, context_options)
            return nil if price.new_record? || price.compare_at_amount.blank?

            price.compare_at_amount
          end

          def display_compare_at_price(product_or_variant, currency, context_options = {})
            price = find_price(product_or_variant, currency, context_options)
            return nil if price.new_record? || price.compare_at_amount.blank?

            Spree::Money.new(price.compare_at_amount, currency: currency).to_s
          end

          private

          def build_pricing_context(variant, currency, options)
            Spree::Pricing::Context.new(
              variant: variant,
              currency: currency,
              store: options[:store],
              zone: options[:tax_zone] || options[:zone],
              user: options[:user],
              quantity: options[:quantity]
            )
          end
        end
      end
    end
  end
end
