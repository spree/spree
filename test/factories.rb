Factory.define :order do |f|
  f.shipments do |shipments|
    [shipments.association(:shipment)]
  end
  f.association :bill_address, :factory => :address
  f.association :ship_address, :factory => :address
end

Factory.define :shipment do |f|
  f.association :shipping_method
end

Factory.define :shipping_method do |f|
  f.shipping_calculator "Spree::FlatRateShipping::Calculator"
  f.association :zone
end

Factory.define :zone do |f|
  f.name { Factory.next(:name) }
end

Factory.define :address do |f|
  f.firstname "Frank"
  f.lastname "Foo"
  f.city "Fooville"
  f.address1 "99 Foo St."
  f.zipcode "12345"
  f.phone "555-555-1212"
  f.state_name "Foo Province"
  f.association :country
end

Factory.define :product do |f|
  f.name "Foo Product"
  f.master_price 19.99
  f.variants do |variants|
    [Factory(:variant, :option_values => []), variants.association(:variant)]
  end
end

Factory.define :option_value do |f|
end

Factory.define :empty_variant, :class => :Variant do |f|
  f.price 19.99
end

Factory.define :variant do |f|
  f.price 19.99
  f.option_values { [Factory(:option_value)] }  
end

Factory.define :inventory_unit do |f|
end

Factory.define :country do |f|
  f.name { Factory.next(:name) }
end

Factory.sequence :name do |n|
  "Foo_#{n}"
end

Factory.define :creditcard do |f|
  f.verification_value 123
  f.month 12
  f.year 2013
  f.number 4111111111111111
end