Spree::Sample.load_sample('option_types')

color_option_type = Spree::OptionType.find_by!(name: 'color')
length_option_type = Spree::OptionType.find_by!(name: 'length')
size_option_type = Spree::OptionType.find_by!(name: 'size')

colors = {
  white: '#FFFFFF',
  purple: '#800080',
  red: '#FF0000',
  black: '#000000',
  brown: '#8B4513',
  green: '#228C22',
  grey: '#808080',
  orange: '#FF8800',
  burgundy: '#A8003B',
  beige: '#E1C699',
  mint: '#AAF0D1',
  blue: '#0000FF',
  dark_blue: '#00008b',
  khaki: '#BDB76B',
  yellow: '#FFFF00',
  light_blue: '#add8e6',
  pink: '#FFA6C9',
  lila: '#cf9de6',
  ecru: '#F4F2D6'
}

lengths = { mini: 'Mini', midi: 'Midi', maxi: 'Maxi' }

sizes = { xs: 'XS', s: 'S', m: 'M', l: 'L', xl: 'XL' }

colors.each_with_index do |color, index|
  color_option_type.option_values.find_or_create_by!(
    name: color.first,
    presentation: color.last,
    position: index + 1
  )
end

lengths.each_with_index do |length, index|
  length_option_type.option_values.find_or_create_by!(
    name: length.first,
    presentation: length.last,
    position: index + 1
  )
end

sizes.each_with_index do |size, index|
  size_option_type.option_values.find_or_create_by!(
    name: size.first,
    presentation: size.last,
    position: index + 1
  )
end
