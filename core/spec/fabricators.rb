require 'fabrication'

Fabricator(:product) do
  name { Fabricate.sequence(:product_name){|n| "Product ##{n}"} }
  description 'Description'
  price 100
  sku "ABC"
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
  environment 'test'
  description 'Payment Method'
end
