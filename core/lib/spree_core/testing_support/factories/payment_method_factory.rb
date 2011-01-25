Factory.define :payment_method, :class => 'PaymentMethod::Check' do |f|
  f.name 'Check'
  f.environment 'cucumber'
  f.display_on :front_end
end
