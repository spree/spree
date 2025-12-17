module Spree
  module CheckoutHelper
    def checkout_progress(numbers: false)
      states = (@order.checkout_steps - ['complete']).unshift('cart')
      states -= ['delivery'] if !@order.requires_ship_address? || !@order.delivery_required?

      items = states.each_with_index.map do |state, i|
        text = Spree.t("order_state.#{state}").titleize
        text.prepend("#{i.succ}. ") if numbers

        css_classes = ['breadcrumb-item']

        # cart is not included in checkout_steps, so we need to handle it separately
        if @order.passed_checkout_step?(state) || state == 'cart'
          link_content = text
          link_url = if state == 'cart'
                       # using absolute URL if using headless storefronts
                       spree.cart_url(host: current_store.url_or_custom_domain, order_token: @order.token)
                     else
                       spree.checkout_state_path(@order.token, state)
                     end

          text = link_to(link_content, link_url)
          css_classes << 'text-zinc-950'
          content_tag('li', text, class: css_classes.join(' '))
        else
          content_tag('li', text, class: "breadcrumb-item #{state == @order.state ? 'font-bold' : 'text-gray-950'}")
        end
      end
      content_tag('ol', raw(items.join("\n")), class: 'breadcrumb flex items-center py-6 gap-2', id: "checkout-step-#{@order.state}")
    end

    def checkout_available_payment_methods
      @checkout_available_payment_methods ||= @order.collect_frontend_payment_methods.reject(&:store_credit?)
    end

    def checkout_started?
      (@order.state == 'address' && @order.state_was == 'cart') || (@order.state == 'cart' && correct_state == 'address')
    end

    def already_have_an_account?
      @already_have_an_account ||= @order.email.present? && Spree.user_class.exists?(email: @order.email.downcase)
    end

    def checkout_payment_sources(payment_method = nil)
      return [] unless try_spree_current_user.respond_to?(:payment_sources)

      payment_method.present? ? try_spree_current_user.payment_sources.where(payment_method: payment_method) : try_spree_current_user.payment_sources
    end

    def quick_checkout_enabled?(order)
      order.quick_checkout_available?
    end

    def can_use_store_credit_on_checkout?(order)
      order.could_use_store_credit? && (!order.respond_to?(:gift_card) || !order.gift_card.present?)
    end
  end
end
