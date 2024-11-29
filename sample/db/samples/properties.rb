properties = {
  brand: 'Brand',
  model: 'Model',
  manufacturer: 'Manufacturer',
  made_from: 'Made from',
  fit: 'Fit',
  gender: 'Gender',
  type: 'Type',
  size: 'Size',
  material: 'Material',
  length: 'Lenght',
  color: 'Color',
  collection: 'Collection'
}

properties_data = properties.map do |name, presentation|
  { name: name, presentation: presentation }
end

Spree::Property.insert_all(properties_data)

Spree::Property.where(name: %w[brand manufacturer]).update(filterable: true)
