Spree::Sample.load_sample('products')

metafield_values = {
  manufacturer: %w[Wilson Jerseys Wannabe Resiliance Conditioned],
  brand: %w[Alpha Beta Gamma Delta Theta Epsilon Zeta],
  material: ['90% Cotton 10% Elastan', '50% Cotton 50% Elastan', '10% Cotton 90% Elastan'],
  fit: %w[Form Lose]
}

Spree::Product.find_each do |product|
  product.set_metafield('properties.manufacturer', metafield_values[:manufacturer].sample)
  product.set_metafield('properties.brand', metafield_values[:brand].sample)
  product.set_metafield('properties.material', metafield_values[:material].sample)
  product.set_metafield('properties.fit', metafield_values[:fit].sample)
  product.save! if product.changed?
end
