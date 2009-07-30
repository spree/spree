Factory.sequence(:product_sequence) {|n| "Product ##{n} - #{rand(9999)}"}

Factory.define :product do |f|
  f.name { Factory.next(:product_sequence) }
  f.master_price 19.99
  f.description { Faker::Lorem.paragraphs(rand(5)+1).join("\n") }

  # associations:
  f.tax_category {|r| TaxCategory.find(:first) || r.association(:tax_category)}
  f.shipping_category {|r| ShippingCategory.find(:first) || r.association(:shipping_category)}
  
  f.variants do |variants|
    [Factory(:variant, :option_values => []), variants.association(:variant)]
  end
end