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

Spree::OptionType.insert_all!(option_types_attributes)
