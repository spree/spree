color = Spree::OptionType.find_or_initialize_by(name: 'color')
color.presentation = 'Color'
color.kind = 'color_swatch'
color.save!
