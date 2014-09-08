prototypes = [
  {
    :name => "מוצר חלב",
    :properties => ["יצרן", "משקל"]
  }
]

prototypes.each do |prototype_attrs|
  prototype = Spree::Prototype.create!(:name => prototype_attrs[:name])
  prototype_attrs[:properties].each do |property|
    prototype.properties << Spree::Property.find_by_name!(property)
  end
end
