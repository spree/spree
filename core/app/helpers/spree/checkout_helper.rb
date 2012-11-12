module Spree
  module CheckoutHelper
    def checkout_states
      @order.checkout_steps
    end

    def state_required_class
      'required' if state_required?
    end

    def state_required_label
      if state_required?
        content_tag :span, '*', :class => state_required_class
      end
    end

    def checkout_progress
      states = checkout_states
      items = states.map do |state|
        text = t("order_state.#{state}").titleize

        css_classes = []
        current_index = states.index(@order.state)
        state_index = states.index(state)

        if state_index < current_index
          css_classes << 'completed'
          text = link_to text, checkout_state_path(state)
        end

        css_classes << 'next' if state_index == current_index + 1
        css_classes << 'current' if state == @order.state
        css_classes << 'first' if state_index == 0
        css_classes << 'last' if state_index == states.length - 1
        # It'd be nice to have separate classes but combining them with a dash helps out for IE6 which only sees the last class
        content_tag('li', content_tag('span', text), :class => css_classes.join('-'))
      end
      content_tag('ol', raw(items.join("\n")), :class => 'progress-steps', :id => "checkout-step-#{@order.state}")
    end

    private
    def state_required?
      Spree::Config[:address_requires_state]
    end
  end
end
