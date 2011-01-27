Factory.define :product_option_type do |f|
  f.product { Factory(:product) }
  f.option_type { Factory(:option_type) }
end
