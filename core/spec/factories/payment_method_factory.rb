Factory.define :payment_method, :class => 'PaymentMethod::Check' do |f|
  f.name 'Check'
  f.environment 'cucumber'
end
