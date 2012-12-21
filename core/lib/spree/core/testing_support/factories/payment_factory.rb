FactoryGirl.define do
  factory :payment, :class => Spree::Payment do
    amount 45.75
    payment_method { FactoryGirl.create(:bogus_payment_method) }
    source { FactoryGirl.build(:credit_card) }
    order { FactoryGirl.create(:order) }
    state 'pending'
    response_code '12345'
  end
end
