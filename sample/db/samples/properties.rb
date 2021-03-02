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
  Spree::Property.where(name: name, presentation: presentation).first_or_create!
end
