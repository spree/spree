module SpreeStripe
  class PaymentIntentPresenter
    SETUP_FUTURE_USAGE = 'off_session'.freeze

    # @param order [Spree::Cart, Spree::Order]
    # @param customer [String, nil] Stripe customer id, eg. cus_123
    # @param payment_method_id [String, nil] Stripe payment method id, eg. pm_123
    def initialize(amount:, order:, customer: nil, payment_method_id: nil, capture_method: nil)
      @amount = amount
      @order = order
      @customer = customer
      @ship_address = order.ship_address
      @payment_method_id = payment_method_id
      @capture_method = capture_method
    end

    # @return [Hash]
    def call
      payload = payment_method_id.present? ? saved_payment_method_payload : new_payment_method_payload
      payload = payload.deep_merge(basic_payload)
      payload = payload.merge(capture_method: Gateway::PaymentIntents::MANUAL_CAPTURE_METHOD) if manual_capture?

      return payload unless ship_address

      # Stripe requires address1, which Spree does not always demand.
      if ship_address.invalid? || ship_address.address1.blank?
        ship_address.errors.clear
        return payload
      end

      payload.merge(ship_address_payload)
    end

    def ship_address_payload
      {
        shipping: {
          address: {
            city: ship_address.city,
            country: ship_address.country_iso,
            line1: ship_address.address1,
            line2: ship_address.address2,
            postal_code: ship_address.zipcode,
            state: ship_address.state_abbr
          },
          name: ship_address.full_name
        }
      }
    end

    private

    attr_reader :order, :amount, :customer, :ship_address, :payment_method_id, :capture_method

    def manual_capture?
      capture_method.to_s == Gateway::PaymentIntents::MANUAL_CAPTURE_METHOD
    end

    def basic_payload
      {
        amount: amount,
        customer: customer,
        currency: order.currency,
        statement_descriptor_suffix: statement_descriptor_suffix,
        automatic_payment_methods: { enabled: true },
        transfer_group: order.number,
        metadata: { spree_order_id: order.id }
      }
    end

    def statement_descriptor_suffix
      SpreeStripe::StatementDescriptorSuffixPresenter.new(order_description: order.number).call
    end

    def new_payment_method_payload
      {
        payment_method_options: {
          card: { setup_future_usage: SETUP_FUTURE_USAGE },
          sepa_debit: { setup_future_usage: SETUP_FUTURE_USAGE }
        }
      }
    end

    def saved_payment_method_payload
      { payment_method: payment_method_id }
    end
  end
end
