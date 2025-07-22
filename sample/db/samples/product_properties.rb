Spree::Sample.load_sample('products')

property_values = {
  manufacturers: %w[Wilson Jerseys Wannabe Resiliance Conditioned],
  brands: %w[Alpha Beta Gamma Delta Theta Epsilon Zeta],
  materials: ['90% Cotton 10% Elastan', '50% Cotton 50% Elastan', '10% Cotton 90% Elastan'],
  fits: %w[Form Lose]
}

properties = Spree::Property.insert_all([
  { name: 'manufacturer', presentation: 'Manufacturer' },
  { name: 'brand', presentation: 'Brand' },
  { name: 'material', presentation: 'Material' },
  { name: 'fit', presentation: 'Fit' },
])

properties_ids = properties.rows.flatten
properties_to_insert = Spree::Product.all.ids.flat_map do |product_id|
  [
    { product_id: product_id, property_id: properties_ids.first, value: property_values[:manufacturers].sample },
    { product_id: product_id, property_id: properties_ids.second, value: property_values[:brands].sample },
    { product_id: product_id, property_id: properties_ids.third, value: property_values[:materials].sample },
    { product_id: product_id, property_id: properties_ids.fourth, value: property_values[:fits].sample },
  ]
end

Spree::ProductProperty.insert_all(properties_to_insert)
