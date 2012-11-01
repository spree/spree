FactoryGirl.define do
  factory :payment_method, :class => Spree::PaymentMethod::Check do
    name 'Check'
    environment 'test'
  end

  factory :bogus_payment_method, :class => Spree::Gateway::Bogus do
    name 'Credit Card'
    environment 'test'
  end

  # authorize.net was moved to spree_gateway. Leaving this factory
  # in place with bogus in case anyone is using it
  factory :authorize_net_payment_method, :class => Spree::Gateway::BogusSimple do
    name 'Credit Card'
    environment 'test'
  end
end
