module Spree
  module CheckoutAnalyticsHelper
    def coupon_tracking_params
      {
        order: @order,
        coupon_code: params[:coupon_code],
        coupon_handler: @result
      }
    end

    def clean_analytics_session
      session.delete(:checkout_started)
      session.delete(:checkout_step_viewed)
      session.delete(:checkout_step_completed)
    end

    def clear_checkout_completed_session
      session.delete(:checkout_completed)
    end

    def order_tracking_params
      {
        last_ip_address: request.remote_ip,
      }
    end

    def track_checkout_started
      # server-side tracking
      track_event('checkout_started', { order: @order })

      # client-side tracking
      session[:checkout_started] = true
    end

    def track_checkout_entered_email
      return unless @order.email.present?
      return unless params.dig(:order, :email).present?

      track_event('checkout_email_entered', { order: @order, email: @order.email })
    end

    def track_payment_info_entered
      return unless @order.payment_method.present?
      return unless params.dig(:order, :payments_attributes).present?

      track_event('payment_info_entered', { order: @order })
    end

    def track_checkout_step_viewed
      # server-side tracking
      track_event('checkout_step_viewed', { order: @order, step: params[:state] || @order.state })

      # client-side tracking
      trackable_checkout_steps = @order.checkout_steps[0..2]
      session[:checkout_step_viewed] = true if trackable_checkout_steps.include? @order.state
    end

    def track_checkout_step_completed
      # server-side tracking
      track_event('checkout_step_completed', { order: @order, step: @previous_state })

      # client-side tracking
      session[:checkout_step_completed] = @previous_state # for 3rd party frontend tracking
    end

    def track_checkout_completed
      # server-side tracking
      track_event('order_completed', { order: @order })

      # client-side tracking
      session[:checkout_completed] = true
    end
  end
end
