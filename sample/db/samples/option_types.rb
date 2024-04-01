option_types_attributes = [
  {
    name: 'color',
    presentation: 'Колір',
    position: 1
  },
  {
    name: 'length',
    presentation: 'Довжина',
    position: 2
  },
  {
    name: 'size',
    presentation: 'Розмір',
    position: 3
  },
]
option_types_attributes.each do |attrs|
  unless Spree::OptionType.where(attrs).exists?
    Spree::OptionType.create!(attrs)
  end
end

color_type = Spree::OptionType.find_by(name: 'color')
color_type.name_en = 'color'
color_type.presentation_en = 'Color'
color_type.save!

length_type = Spree::OptionType.find_by(name: 'length')
length_type.name_en = 'length'
length_type.presentation_en = 'Length'
length_type.save!

size_type = Spree::OptionType.find_by(name: 'size')
size_type.name_en = 'size'
size_type.presentation_en = 'Size'
size_type.save!
