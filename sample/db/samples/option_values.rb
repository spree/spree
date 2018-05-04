Spree::Sample.load_sample('option_types')

size = Spree::OptionType.find_by!(presentation: 'Size')
color = Spree::OptionType.find_by!(presentation: 'Color')

option_values_attributes = [
  {
    name: 'Small',
    presentation: 'S',
    position: 1,
    option_type: size
  },
  {
    name: 'Medium',
    presentation: 'M',
    position: 2,
    option_type: size
  },
  {
    name: 'Large',
    presentation: 'L',
    position: 3,
    option_type: size
  },
  {
    name: 'Extra Large',
    presentation: 'XL',
    position: 4,
    option_type: size
  },
  {
    name: 'Red',
    presentation: 'Red',
    position: 1,
    option_type: color
  },
  {
    name: 'Green',
    presentation: 'Green',
    position: 2,
    option_type: color
  },
  {
    name: 'Blue',
    presentation: 'Blue',
    position: 3,
    option_type: color
  }
]

option_values_attributes.each do |attrs|
  Spree::OptionValue.where(attrs).first_or_create!
end
