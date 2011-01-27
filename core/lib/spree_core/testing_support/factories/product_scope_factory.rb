Factory.define :product_scope do |f|
  f.product_group { Factory(:product_group) }
  f.name "on_hand"
  f.arguments "some arguments"
end

