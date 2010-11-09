require 'fabrication'

Fabricator(:user) do
  email { Fabricate.sequence(:user_email) { |n| "user#{n}@example.org" } }
  login { |u| u.email }
  authenticity_token { Fabricate.sequence(:user_authenticity_token) { |n| "#{n}#{n}#{n}xxx#{n}#{n}#{n}xxx"}}
  password "secret"
  password_confirmation { |u| u.password }
end

Fabricator(:product) do
  name { Fabricate.sequence(:product_name){|n| "Product ##{n}"} }
  description 'Description'
  price 100
  sku "ABC"
end

Fabricator(:line_item) do
  price 100
  quantity 1
  variant_id { Fabricate(:product).id }
end

Fabricator(:order) do
  number { Fabricate.sequence(:order_number) { |n| "R#{n}" } }
  user { Fabricate(:user).id }
  email { Fabricate.sequence(:order_email) { |n| "user#{n}@example.org" } }
end

Fabricator(:payment_method) do
  active true
  environment 'test'
  description 'Payment Method'
end

Fabricator(:"payment_method_check", :class_name => "PaymentMethod::Check", :from => :payment_method) do
  name "Check"
end

Fabricator(:calculator_flat_rate, :class_name => "Calculator::FlatRate") do
end

Fabricator(:shipping_method) do
  name 'UPS'
  zone_id 2
  after_create { |shipping_method| Fabricate(:calculator_flat_rate, :calculable => shipping_method) }
end

Fabricator(:address) do
  firstname "Joe"
  lastname "Doe"
  address1 "42nd street"
  city "New York"
  state_name "New York"
  zipcode "10013"
  phone "123456789"
end
