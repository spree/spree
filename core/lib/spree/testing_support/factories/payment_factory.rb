FactoryGirl.define do
  factory :payment, class: Spree::Payment do
    amount 45.75
    association(:payment_method, factory: :bogus_payment_method)
    association(:source, factory: :credit_card)
    order
    state 'checkout'
    response_code '12345'
  end

  factory :check_payment, class: Spree::Payment do
    amount 45.75
    payment_method
    order
  end
end
