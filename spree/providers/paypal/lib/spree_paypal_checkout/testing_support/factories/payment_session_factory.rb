FactoryBot.define do
  factory :paypal_checkout_payment_session, class: 'Spree::PaymentSessions::PaypalCheckout' do
    transient do
      owner { create(:order_with_line_items) }
    end

    cart { owner if owner.is_a?(Spree::Cart) }
    order { owner unless owner.is_a?(Spree::Cart) }
    payment_method { create(:paypal_checkout_gateway, store: owner.store) }
    amount { owner.total }
    currency { owner.currency }
    status { 'pending' }
    external_id { SecureRandom.alphanumeric(17).upcase }
    external_data { { 'client_id' => 'paypal_client_id_test', 'intent' => 'CAPTURE' } }
  end
end
