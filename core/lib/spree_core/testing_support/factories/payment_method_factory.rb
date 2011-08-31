FactoryGirl.define do
  factory :payment_method, :class => PaymentMethod::Check do
    name 'Check'
    environment 'cucumber'
    #display_on :front_end
  end

  factory :bogus_payment_method, :class => Gateway::Bogus do
    name 'Credit Card'
    environment 'cucumber'
    #f.display_on :front_end
  end

  factory :authorize_net_payment_method, :class => Gateway::AuthorizeNet do
    name 'Credit Card'
    environment 'cucumber'
    #display_on :front_end
  end
end