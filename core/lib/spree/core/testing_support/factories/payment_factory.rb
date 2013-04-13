FactoryGirl.define do
  factory :payment, :class => Spree::Payment do
    amount 45.75
    payment_method { FactoryGirl.create(:bogus_payment_method) }
    source { FactoryGirl.build(:credit_card) }
    order { FactoryGirl.create(:order) }
    state 'checkout'
    response_code '12345'

  end

  factory :check_payment, :class => Spree::Payment do
    amount 45.75
    payment_method { FactoryGirl.create(:payment_method) }
    order { FactoryGirl.create(:order) }
  end
end
