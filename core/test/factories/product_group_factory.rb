Factory.sequence(:product_group_sequence) {|n| "Product Group ##{n} - #{rand(9999)}"}

Factory.define :product_group do |f|
  f.name { Factory.next(:product_group_sequence) }

  f.product_scopes_attributes([
      { :name => "price_between", :arguments => [10,20]},
      {:name => "name_contains", :arguments => ["ruby"]}
  ])
end