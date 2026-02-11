manufacturers = %w[Wilson Jerseys Wannabe Resiliance Conditioned]
materials = ['90% Cotton 10% Elastan', '50% Cotton 50% Elastan', '10% Cotton 90% Elastan']
fits = %w[Form Lose]

Spree::Product.find_each.with_index do |product, index|
  product.set_metafield('properties.manufacturer', manufacturers[index % manufacturers.length])
  product.set_metafield('properties.material', materials[index % materials.length])
  product.set_metafield('properties.fit', fits[index % fits.length])
  product.save! if product.changed?
end
