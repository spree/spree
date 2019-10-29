Spree::Sample.load_sample('option_types')

color_option_type = Spree::OptionType.find_by!(name: 'color')
length_option_type = Spree::OptionType.find_by!(name: 'length')
size_option_type = Spree::OptionType.find_by!(name: 'size')

colors = %w(
  white
  purple
  red
  black
  brown
  green
  grey
  orange
  burgundy
  beige
  mint
  blue
  dark_blue
  khaki
  yellow
  light_blue
  pink
  lila
  ecru
)

lengths = %w(mini midi maxi)
sizes = %w(xs s m l xl)

colors.each_with_index do |color, index|
  color_option_type.option_values.find_or_create_by!(
    name: color,
    presentation: color.humanize,
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
