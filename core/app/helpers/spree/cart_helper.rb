module Spree
  module CartHelper
    def add_to_cart_button(variant)
      button_tag class: 'btn btn-primary w-100 text-uppercase font-weight-bold add-to-cart-button', type: :submit do
        Spree.t(:add_to_cart)
      end
    end

    def quantity_field_options(opts = {})
      opts[:min]   ||= 1
      opts[:max]   ||= maximum_quantity
      opts[:class] ||= 'p-0 flex-grow-1 flex-shrink-1 text-center form-control border-left-0 border-right-0 quantity-select-value'

      {
        min: opts[:min], max: opts[:max],
        class: opts[:class],
        data: { 'cart-form-target': 'quantity', 'quantity-picker-target': 'quantity' },
        aria: { label: Spree.t(:quantity) }
      }
    end

    def quantity_modifier_button_tag(text = '+', opts = {})
      opts[:action] ||= 'increase'
      opts[:type]   ||= 'button'

      opts[:class] ||= 'flex-grow-0 flex-shrink-0 py-0 px-3'
      opts[:class] += " quantity-select-#{opts[:action]}"
      opts[:class] += if opts[:action] == 'increase'
                        ' border-left-0'
                      else
                        ' border-right-0'
                      end

      button_tag text, type: opts[:type], class: opts[:class], data: { action: "click->quantity-picker##{opts[:action]}" }
    end
  end
end
