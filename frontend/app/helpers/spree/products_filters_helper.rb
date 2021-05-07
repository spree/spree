module Spree
  module ProductsFiltersHelper
    def min_price_filter_input
      price_filter_input(name: :min_price, value: prices.first, placeholder: Spree.t(:min))
    end

    def max_price_filter_input
      price_filter_input(name: :max_price, value: prices.last, placeholder: Spree.t(:max))
    end

    def price_filter_input(name:, value:, placeholder:)
      price_value = value&.zero? ? '' : value
      number_field_tag(name, price_value, min: 0, step: 1, placeholder: placeholder)
    end

    private

    def prices
      price_param = params[:price].to_s
      split_prices = price_param.split('-')
      split_prices.map { |price| price.to_money.to_i }
    end
  end
end
