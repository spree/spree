module Spree
  module CheckoutHelper
    def checkout_progress(numbers: false)
      states = @order.checkout_steps - ['complete']
      items = states.each_with_index.map do |state, i|
        text = Spree.t("order_state.#{state}").titleize
        text.prepend("#{i.succ}. ") if numbers

        css_classes = ['text-uppercase nav-item']
        current_index = states.index(@order.state)
        state_index = states.index(state)

        if state_index < current_index
          css_classes << 'completed'
          link_content = content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
          link_content << text
          text = link_to(link_content, spree.checkout_state_path(state), class: 'd-flex flex-column align-items-center', method: :get)
        end

        css_classes << 'next' if state_index == current_index + 1
        css_classes << 'active' if state == @order.state
        css_classes << 'first' if state_index == 0
        css_classes << 'last' if state_index == states.length - 1
        # No more joined classes. IE6 is not a target browser.
        # Hack: Stops <a> being wrapped round previous items twice.
        if state_index < current_index
          content_tag('li', text, class: css_classes.join(' '))
        else
          link_content = if state == @order.state
                           content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
                         else
                           inline_svg_tag 'circle.svg', class: 'checkout-progress-steps-image'
                         end
          link_content << text
          content_tag('li', content_tag('a', link_content, class: "d-flex flex-column align-items-center #{'active' if state == @order.state}"), class: css_classes.join(' '))
        end
      end
      content = content_tag('ul', raw(items.join("\n")), class: 'nav justify-content-between checkout-progress-steps', id: "checkout-step-#{@order.state}")
      hrs = '<hr />' * (states.length - 1)
      content << content_tag('div', raw(hrs), class: "checkout-progress-steps-line state-#{@order.state}")
    end

    def checkout_available_payment_methods
      @checkout_available_payment_methods ||= @order.available_payment_methods(current_store)
    end

    def checkout_edit_link(step = 'address', order = @order)
      return if order.complete?

      classes = 'align-text-bottom checkout-confirm-delivery-informations-link'

      link_to spree.checkout_state_path(step), class: classes, method: :get do
        inline_svg_tag 'edit.svg'
      end
    end

    def credit_card_icon(type)
      available_icons = %w[visa american_express diners_club discover jcb maestro master]

      if available_icons.include?(type)
        image_tag "credit_cards/icons/#{type}.svg", class: 'payment-sources-list-item-image'
      else
        image_tag 'credit_cards/icons/generic.svg', class: 'payment-sources-list-item-image'
      end
    end
  end
end
