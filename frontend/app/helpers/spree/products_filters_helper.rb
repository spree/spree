module Spree
  module ProductsFiltersHelper
    PRICE_FILTER_NAME = 'price'.freeze

    FILTER_LINK_CSS_CLASSES = 'd-inline-block text-uppercase py-1 px-2 m-1 plp-overlay-card-item'.freeze
    ACTIVE_FILTER_LINK_CSS_CLASSES = 'plp-overlay-card-item--selected'.freeze

    CLEAR_ALL_FILTERS_LINK_CSS_CLASSES = 'btn spree-btn btn-outline-primary w-100 mb-4'.freeze

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

    def option_value_filter_link(option_value, permitted_params, opts = {})
      id = option_value.id
      ot_downcase_name = option_value.option_type.filter_param
      selected_option_values = params[ot_downcase_name]&.split(',')&.map(&:to_i) || []
      is_selected = selected_option_values.include?(id)
      option_value_param = (is_selected ? selected_option_values - [id] : selected_option_values + [id]).join(',')
      new_params = permitted_params.merge(ot_downcase_name => option_value_param, menu_open: 1)

      link_to new_params, data: { params: new_params, id: id, filter_name: ot_downcase_name, multiselect: true } do
        # TODO: refactor this
        if color_option_type_name.present? && color_option_type_name.downcase == ot_downcase_name
          content_tag :span, class: 'd-inline-block mb-1' do
            render partial: 'spree/shared/color_select', locals: {
              color: option_value.presentation,
              selected: is_selected
            }
          end
        else
          filter_content_tag(option_value.name, opts.merge(is_selected: is_selected))
        end
      end
    end

    def property_value_filter_link(property, value, permitted_params, opts = {})
      id = value.first
      name = value.last

      selected_properties = params.dig(:properties, property.filter_param)&.split(',') || []
      is_selected = selected_properties.include?(id)
      property_values = (is_selected ? selected_properties - [id] : selected_properties + [id])
      url = permitted_params.merge(properties: { property.filter_param => property_values }, menu_open: 1)
      filter_name = "properties[#{property.filter_param}]"
      new_params = permitted_params.merge(filter_name => property_values, menu_open: 1)

      base_filter_link(url, name, opts.merge(params: new_params, is_selected: is_selected, filter_name: filter_name, id: id, multiselect: true))
    end

    def price_filter_link(price_range, permitted_params, opts = {})
      is_selected = params[:price] == price_range.to_param
      price_param = is_selected ? '' : price_range.to_param
      url = permitted_params.merge(price: price_param, menu_open: 1)

      opts[:is_selected] ||= is_selected

      content_tag :div do
        base_filter_link(url, price_range, opts.merge(is_selected: is_selected, filter_name: PRICE_FILTER_NAME, id: price_param))
      end
    end

    def product_filters_present?(permitted_params)
      properties = permitted_params.fetch(:properties, {}).to_unsafe_h
      flatten_params = permitted_params.to_h.merge(properties)

      flatten_params.any? { |name, value| product_filter_present?(name, value) }
    end

    def clear_all_filters_link(permitted_params, opts = {})
      opts[:css_class] ||= CLEAR_ALL_FILTERS_LINK_CSS_CLASSES
      sort_by_param = permitted_params.slice(:sort_by)

      link_to Spree.t('plp.clear_all'), sort_by_param, class: opts[:css_class], data: { params: sort_by_param }
    end

    private

    def product_filter_present?(filter_param, filter_value)
      filter_param.in?(product_filters_params) && filter_value.present?
    end

    def product_filters_params
      options_filter_params = OptionType.filterable.map(&:filter_param)
      properties_filter_params = Property.filterable.pluck(:filter_param)

      options_filter_params + properties_filter_params + [PRICE_FILTER_NAME]
    end

    def base_filter_link(url, label, opts = {})
      opts[:params] ||= url

      link_to url, data: { filter_name: opts[:filter_name], id: opts[:id], params: opts[:params], multiselect: opts[:multiselect] } do
        filter_content_tag(label, opts)
      end
    end

    def filter_content_tag(label, opts = {})
      opts[:css_class]        ||= FILTER_LINK_CSS_CLASSES
      opts[:css_active_class] ||= ACTIVE_FILTER_LINK_CSS_CLASSES

      content_tag :div, class: "#{opts[:css_class]} #{opts[:css_active_class] if opts[:is_selected]}" do
        label.to_s
      end
    end

    def filters_price_range_from_param
      Filters::PriceRangePresenter.from_param(params[:price].to_s, currency: current_currency)
    end

    def filters_price_range(min_amount, max_amount)
      Filters::PriceRangePresenter.new(
        min_price: filters_price(min_amount),
        max_price: filters_price(max_amount)
      )
    end

    def filters_less_than_price_range(amount)
      Filters::QuantifiedPriceRangePresenter.new(price: filters_price(amount), quantifier: :less_than)
    end

    def filters_more_than_price_range(amount)
      Filters::QuantifiedPriceRangePresenter.new(price: filters_price(amount), quantifier: :more_than)
    end

    def filters_price(amount)
      Filters::PricePresenter.new(amount: amount, currency: current_currency)
    end
  end
end
