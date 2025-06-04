module Spree
  module CartHelper
    def quantity_field_options(opts = {})
      opts[:min]   ||= 1
      opts[:max]   ||= maximum_quantity

      {
        min: opts[:min], max: opts[:max],
        class: opts[:class],
        data: { 'quantity-picker-target': 'quantity' },
        aria: { label: Spree.t(:quantity) }
      }
    end

    def quantity_modifier_button_tag(text = '+', opts = {})
      opts[:action] ||= 'increase'
      opts[:type]   ||= 'button'

      button_tag(
        text,
        type: opts[:type],
        class: opts[:class],
        data: {
          'quantity-picker-target': opts[:action],
          action: "click->quantity-picker##{opts[:action]} click->cart#disableCart turbo-stream-form:submit-end->cart#enableCart"
        }
      )
    end

    def color_options_style_for_line_items(line_items)
      @color_options_style_for_line_items = begin
        colors = line_items.map(&:variant).map do |v|
          color_option_values = v.option_values.find_all do |ov|
            ov.option_type.color?
          end

          color_option_values.map do |ov|
            { name: ov.name, filter_name: ov.name }
          end
        end

        colors = colors.flatten.uniq { |color| [color[:name], color[:filter_name]] }

        Spree::ColorsPreviewStylesPresenter.new(colors).to_s
      end
    end

    def cart_id(order)
      return 'cart_contents' if order.blank? || order.id.blank? || order.updated_at.blank?

      "cart_contents_#{order.id}_#{order.updated_at.to_i}"
    end
  end
end
