FactoryGirl.define do
  factory :payment_method, :class => Spree::PaymentMethod::Check do
    name 'Check'
    environment 'test'
    #display_on :front_end
  end

  factory :bogus_payment_method, :class => Spree::Gateway::Bogus do
    name 'Credit Card'
    environment 'test'
    #display_on :front_end
  end

  factory :authorize_net_payment_method, :class => Spree::Gateway::AuthorizeNet do
    name 'Credit Card'
    environment 'test'
    #display_on :front_end
  end
end
