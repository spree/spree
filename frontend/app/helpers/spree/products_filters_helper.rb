module Spree
  module ProductsFiltersHelper
    def min_price_filter_input(**html_options)
      price_filter_input(
        name: :min_price,
        value: prices.first,
        placeholder: "#{currency_symbol(current_currency)} #{Spree.t(:min)}",
        **html_options
      )
    end

    def max_price_filter_input(**html_options)
      price_filter_input(
        name: :max_price,
        value: prices.last,
        placeholder: "#{currency_symbol(current_currency)} #{Spree.t(:max)}",
        **html_options
      )
    end

    def price_filter_input(name:, value:, placeholder:, **html_options)
      price_value = value&.zero? ? '' : value
      style_class = "spree-flat-input #{html_options[:class]}"

      number_field_tag(
        name, price_value,
        id: name,
        class: style_class,
        min: 0, step: 1, placeholder: placeholder,
        **html_options.except(:class)
      )
    end

    private

    def prices
      price_param = params[:price].to_s
      split_prices = price_param.split('-')
      split_prices.map { |price| price.to_money.to_i }
    end
  end
end
