module Spree
  module ProductsFiltersHelper
    def price_filters
      @price_filters ||= [
        filters_less_than_price_range(50),
        filters_price_range(50, 100),
        filters_price_range(101, 150),
        filters_price_range(151, 200),
        filters_price_range(201, 300),
        filters_more_than_price_range(300)
      ]
    end

    def min_price_filter_input(**html_options)
      price_filter_input(
        name: :min_price,
        value: filters_price_range_from_param.min_price.to_i,
        placeholder: "#{currency_symbol(current_currency)} #{Spree.t(:min)}",
        **html_options
      )
    end

    def max_price_filter_input(**html_options)
      price_filter_input(
        name: :max_price,
        value: filters_price_range_from_param.max_price.to_i,
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

    def filters_price_range_from_param
      Filters::PriceRange.from_param(params[:price].to_s, currency: current_currency)
    end

    def filters_price_range(min_amount, max_amount)
      Filters::PriceRange.new(
        min_price: filters_price(min_amount),
        max_price: filters_price(max_amount)
      )
    end

    def filters_less_than_price_range(amount)
      Filters::QuantifiedPriceRange.new(price: filters_price(amount), quantifier: :less_than)
    end

    def filters_more_than_price_range(amount)
      Filters::QuantifiedPriceRange.new(price: filters_price(amount), quantifier: :more_than)
    end

    def filters_price(amount)
      Filters::Price.new(amount: amount, currency: current_currency)
    end
  end
end
