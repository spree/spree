module Spree
  class PaymentMethod::StoreCredit < ::Spree::PaymentMethod
    def payment_source_class
      ::Spree::StoreCredit
    end

    def can_capture?(payment)
      ['checkout', 'pending'].include?(payment.state)
    end

    def can_void?(payment)
      payment.pending?
    end

    def authorize(amount_in_cents, store_credit, gateway_options = {})
      if store_credit.nil?
        ActiveMerchant::Billing::Response.new(false, Spree.t('store_credit_payment_method.unable_to_find'), {}, {})
      else
        action = lambda do |store_credit|
          store_credit.authorize(
            amount_in_cents / 100.0.to_d,
            gateway_options[:currency],
            action_originator: gateway_options[:originator]
          )
        end
        handle_action_call(store_credit, action, :authorize)
      end
    end

    def capture(amount_in_cents, auth_code, gateway_options = {})
      action = lambda do |store_credit|
        store_credit.capture(
          amount_in_cents / 100.0.to_d,
          auth_code,
          gateway_options[:currency],
          action_originator: gateway_options[:originator]
        )
      end
      handle_action(action, :capture, auth_code)
    end

    def purchase(amount_in_cents, store_credit, gateway_options = {})
      eligible_events = store_credit.store_credit_events.where(
        amount: amount_in_cents / 100.0.to_d,
        action: Spree::StoreCredit::ELIGIBLE_ACTION
      )
      event = eligible_events.detect do |eligible_event|
        store_credit.store_credit_events.where(authorization_code: eligible_event.authorization_code).
          where.not(action: Spree::StoreCredit::ELIGIBLE_ACTION).empty?
      end

      if event.blank?
        ActiveMerchant::Billing::Response.new(false, Spree.t('store_credit_payment_method.unable_to_find'), {}, {})
      else
        capture(amount_in_cents, event.authorization_code, gateway_options)
      end
    end

    def void(auth_code, gateway_options = {})
      action = lambda do |store_credit|
        store_credit.void(auth_code, action_originator: gateway_options[:originator])
      end
      handle_action(action, :void, auth_code)
    end

    def credit(amount_in_cents, auth_code, gateway_options)
      action = lambda do |store_credit|
        currency = gateway_options[:currency] || store_credit.currency
        originator = gateway_options[:originator]

        store_credit.credit(amount_in_cents / 100.0.to_d, auth_code, currency, action_originator: originator)
      end

      handle_action(action, :credit, auth_code)
    end

    def cancel(auth_code)
      store_credit_event = StoreCreditEvent.find_by(authorization_code: auth_code,
                                                    action: Spree::StoreCredit::CAPTURE_ACTION)
      store_credit = store_credit_event.try(:store_credit)

      if !store_credit_event || !store_credit
        handle_action(nil, :cancel, false)
      else
        action = lambda do |store_credit|
          store_credit.credit(store_credit_event.amount, auth_code, store_credit.currency)
        end
        handle_action(action, :cancel, auth_code)
      end
    end

    def source_required?
      true
    end

    def available_for_order?(order)
      order.could_use_store_credit?
    end

    private

    def handle_action_call(store_credit, action, action_name, auth_code = nil)
      store_credit.with_lock do
        if response = action.call(store_credit)
          # note that we only need to return the auth code on an 'auth', but it's innocuous to always return
          ActiveMerchant::Billing::Response.new(
            true,
            Spree.t('store_credit_payment_method.successful_action', action: action_name),
            {},
            authorization: auth_code || response
          )
        else
          ActiveMerchant::Billing::Response.new(false, store_credit.errors.full_messages.join, {}, {})
        end
      end
    end

    def handle_action(action, action_name, auth_code)
      # Find first event with provided auth_code
      store_credit = StoreCreditEvent.find_by(authorization_code: auth_code).try(:store_credit)

      if store_credit.nil?
        ActiveMerchant::Billing::Response.new(
          false,
          Spree.t('store_credit_payment_method.unable_to_find_for_action', auth_code: auth_code, action: action_name),
          {},
          {}
        )
      else
        handle_action_call(store_credit, action, action_name, auth_code)
      end
    end
  end
end
