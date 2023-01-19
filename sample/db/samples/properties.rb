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

properties.each do |name, presentation|
  unless Spree::Property.where(name: name, presentation: presentation).exists?
    Spree::Property.create!(name: name, presentation: presentation)
  end
end

Spree::Property.where(name: %w[brand manufacturer]).update(filterable: true)
