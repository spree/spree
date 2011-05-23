Factory.define :payment_method, :class => 'PaymentMethod::Check' do |f|
  f.name 'Check'
  f.environment 'cucumber'
  #f.display_on :front_end
end

Factory.define :bogus_payment_method, :class => Gateway::Bogus do |f|
  f.name 'Credit Card'
  f.environment 'cucumber'
  #f.display_on :front_end
end

Factory.define :authorize_net_payment_method, :class => Gateway::AuthorizeNet do |f|
  f.name 'Credit Card'
  f.environment 'cucumber'
  #f.display_on :front_end
end
