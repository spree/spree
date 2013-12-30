object @product
cache @product
attributes *product_attributes
node(:display_price) { |p| p.display_price.to_s }
node(:has_variants) { |p| p.has_variants? }
child :master => :master do
  extends "spree/api/variants/show"
end

child :variants => :variants do
  extends "spree/api/variants/show"
end

child :option_types => :option_types do
  extends "spree/api/option_types/show"
end

child :product_properties => :product_properties do
  attributes *product_property_attributes
end
