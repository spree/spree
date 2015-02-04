FactoryGirl.define do
  factory :payment, class: Spree::Payment do
    amount 45.75
    association(:payment_method, factory: :credit_card_payment_method)
    association(:source, factory: :credit_card)
    order
    state 'checkout'
    response_code '12345'

    factory :payment_with_refund do
      state 'completed'
      after :create do |payment|
        create(:refund, amount: 5, payment: payment)
      end
    end
  end

  factory :check_payment, class: Spree::Payment do
    amount 45.75
    association(:payment_method, factory: :check_payment_method)
    order
  end
end
