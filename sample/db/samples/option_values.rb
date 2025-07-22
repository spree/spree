Spree::Sample.load_sample('option_types')

color_option_type = Spree::OptionType.find_by!(name: 'color')
size_option_type = Spree::OptionType.find_by!(name: 'size')

colors = {
  white: 'White',
  purple: 'Purple',
  red: 'Red',
  black: 'Black',
  brown: 'Brown',
  green: 'Green',
  grey: 'Grey',
  orange: 'Orange',
  burgundy: 'Burgundy',
  beige: 'Beige',
  mint: 'Mint',
  blue: 'Blue',
  'dark-blue': 'Dark Blue',
  khaki: 'Khaki',
  yellow: 'Yellow',
  'light-blue': 'Light Blue',
  pink: 'Pink',
  lila: 'Lila',
  ecru: 'Ecru'
}

sizes = { xs: 'XS', s: 'S', m: 'M', l: 'L', xl: 'XL' }

colors.each_with_index do |color, index|
  color_option_type.option_values.find_or_create_by!(name: color.first, presentation: color.last)
end

sizes.each_with_index do |size, index|
  size_option_type.option_values.find_or_create_by!(name: size.first, presentation: size.last)
end
