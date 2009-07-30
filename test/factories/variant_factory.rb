Factory.define(:variant) do |record|
  record.price 19.99
  record.sku    { Faker::Lorem.sentence }
  record.weight { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.height { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.width  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }
  record.depth  { BigDecimal.new("#{rand(200)}.#{rand(99)}") }

  # associations: 
  #record.association(:product, :factory => :product)
  record.option_values { [Factory(:option_value)] }
end

Factory.define :empty_variant, :class => Variant do |f|
  f.price 19.99
end
