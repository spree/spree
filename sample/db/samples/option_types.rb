option_types = [
  {
    :name => "tshirt-size",
    :presentation => "Size",
    :position => 1
  },
  {
    :name => "tshirt-color",
    :presentation => "Color",
    :position => 2
  }
]

option_types.each do |option_type_attrs|
  Spree::OptionType.create!(option_type_attrs, :without_protection => true)
end
