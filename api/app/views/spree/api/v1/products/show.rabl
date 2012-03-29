object @product
attributes *product_attributes
child :variants_including_master => :variants do
  attributes *variant_attributes
end

child :images => :images do
  attributes *image_attributes
end
