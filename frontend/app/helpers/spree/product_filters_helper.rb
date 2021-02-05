module Spree
  module ProductFiltersHelper
    def price_filter_values
      @price_filter_values ||= [
        "#{I18n.t('activerecord.attributes.spree/product.less_than')} #{formatted_price(50)}",
        "#{formatted_price(50)} - #{formatted_price(100)}",
        "#{formatted_price(101)} - #{formatted_price(150)}",
        "#{formatted_price(151)} - #{formatted_price(200)}",
        "#{formatted_price(201)} - #{formatted_price(300)}"
      ]
    end

    def static_filters
      @static_filters ||= Spree::Frontend::Config[:products_filters]
    end

    def additional_filters_partials
      @additional_filters_partials ||= Spree::Frontend::Config[:additional_filters_partials]
    end

    def filtering_params
      @filtering_params ||= available_option_types.map(&:filter_param).concat(static_filters)
    end

    def filtering_params_cache_key
      @filtering_params_cache_key ||= params.permit(*filtering_params)&.reject { |_, v| v.blank? }&.to_param
    end

    def available_option_types_cache_key
      @available_option_types_cache_key ||= Spree::OptionType.filterable.maximum(:updated_at)&.utc&.to_i
    end

    def available_option_types
      @available_option_types ||= Rails.cache.fetch("available-option-types/#{available_option_types_cache_key}") do
        Spree::OptionType.includes(:option_values).filterable.to_a
      end
      @available_option_types
    end

    def color_option_type_name
      @color_option_type_name ||= Spree::OptionType.color&.name
    end

    def formatted_price(value)
      Spree::Money.new(value, currency: current_currency, no_cents_if_whole: true).to_s
    end
  end
end
