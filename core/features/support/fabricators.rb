require 'fabrication'

Fabricator(:product) do
  name { Fabricate.sequence(:product_name){|n| "Product ##{n}"} }
  description 'Description'
  price 100
  sku "ABC"
  available_on { Time.now - 100.days }
end

Fabricator(:line_item) do
  price 100
  quantity 1
  variant_id { Fabricate(:product).master.id }
end

Fabricator(:order) do
end

Fabricator(:payment_method) do
  active true
  environment { Rails.env }
  description 'Payment Method'
end

Fabricator(:adjustment) do
  label I18n.t(:tax)
  amount 5
  mandatory true
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
  country { Country.find(Spree::Config[:default_country_id]) }
end

Fabricator(:user) do
  email { Fabricate.sequence(:user_email) { |n| "user#{n}@example.org" } }
  login { |u| u.email }
  password "secret"
  password_confirmation { |u| u.password }
end
