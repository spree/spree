Factory.define :product_property do |f|
  f.product { Factory(:product) }
  f.property { Factory(:property) }
end
