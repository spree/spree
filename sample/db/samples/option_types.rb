['color', 'size'].each do |name|
  Spree::OptionType.find_or_create_by!(name: name, presentation: name.capitalize)
end
