Factory.sequence(:shipping_category_sequence) {|n| "ShippingCategory ##{n}"}

Factory.define(:shipping_category) do |record|
  record.name { Factory.next(:shipping_category_sequence) } 
end