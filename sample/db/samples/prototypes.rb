Spree::Sample.load_sample('properties')

prototypes = [
  {
    name: 'Shirt',
    properties: ['Manufacturer', 'Brand', 'Model', 'Lenght', 'Made from', 'Material', 'Fit', 'Gender']
  },
  {
    name: 'Bag',
    properties: ['Type', 'Size', 'Material']
  },
  {
    name: 'Mugs',
    properties: ['Size', 'Type']
  }
]

prototypes.each do |prototype_attrs|
  prototype = Spree::Prototype.where(name: prototype_attrs[:name]).first_or_create!
  prototype_attrs[:properties].each do |property_presentation|
    property = Spree::Property.find_by!(presentation: property_presentation)
    prototype.properties << property unless prototype.properties.include?(property)
  end
end
