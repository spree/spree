FactoryBot.define do
  factory :gateway_customer, class: Spree::GatewayCustomer do
    sequence(:profile_id) { |n| "cus_#{n}" }
    customer { |p| p.association(:customer) }
    payment_method { |p| p.association(:payment_method) }
  end
end
