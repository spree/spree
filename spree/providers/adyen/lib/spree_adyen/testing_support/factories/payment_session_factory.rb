FactoryBot.define do
  factory :adyen_payment_session, class: 'Spree::PaymentSessions::Adyen' do
    transient do
      owner { create(:order_with_line_items) }
    end

    cart { owner if owner.is_a?(Spree::Cart) }
    order { owner unless owner.is_a?(Spree::Cart) }
    payment_method { create(:adyen_gateway, :configured, store: owner.store) }
    amount { owner.total }
    currency { owner.currency }
    status { 'pending' }
    external_id { "CS#{SecureRandom.hex(8).upcase}" }
    external_data { { 'session_data' => 'Ab02b4c0!SESSIONDATA', 'manual_capture' => false, 'payable' => false } }
  end

  factory :adyen_payment_setup_session, class: 'Spree::PaymentSetupSessions::Adyen' do
    customer { create(:customer) }
    payment_method { create(:adyen_gateway, :configured) }
    status { 'pending' }
    external_id { "CS#{SecureRandom.hex(8).upcase}" }
    external_data { { 'session_data' => 'Ab02b4c0!SESSIONDATA' } }
  end
end
