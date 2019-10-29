Spree::Sample.load_sample('option_types')

color_option_type = Spree::OptionType.find_by!(name: 'color')
length_option_type = Spree::OptionType.find_by!(name: 'length')
size_option_type = Spree::OptionType.find_by!(name: 'size')

colors = {
  "White" => '#FFFFFF',
  "Purple" => '#800080',
  "Red" => '#FF0000',
  "Black" => '#000000',
  "Brown" => '#8B4513',
  "Green" => '#228C22',
  "Grey" => '#808080',
  "Orange" => '#FF8800',
  "Burgundy" => '#A8003B',
  "Beige" => '#E1C699',
  "Mint" => '#AAF0D1',
  "Blue" => '#0000FF',
  "Dark blue" => '#00008b',
  "Khaki" => '#BDB76B',
  "Yellow" => '#FFFF00',
  "Light blue" => '#add8e6',
  "Pink" => '#FFA6C9',
  "Lila" => '#cf9de6',
  "Ecru" => '#F4F2D6'
}

lengths = %w(mini midi maxi)
sizes = %w(xs s m l xl)

colors.each_with_index do |color, index|
  color_option_type.option_values.find_or_create_by!(
    name: color.first,
    presentation: color.last,
    position: index + 1
  )
end

lengths.each_with_index do |length, index|
  length_option_type.option_values.find_or_create_by!(
    name: length,
    presentation: length.humanize,
    position: index + 1
  )
end

sizes.each_with_index do |size, index|
  size_option_type.option_values.find_or_create_by!(
    name: size,
    presentation: size.upcase,
    position: index + 1
  )
end
