option_types_attributes = [
  {
    name: 'color',
    presentation: 'Color',
    position: 1
  },
  {
    name: 'length',
    presentation: 'Length',
    position: 2
  },
  {
    name: 'size',
    presentation: 'Size',
    position: 3
  },
]

option_types_attributes.each do |attrs|
  Spree::OptionType.where(attrs).first_or_create!
end
