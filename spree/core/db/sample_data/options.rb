color = Spree::OptionType.find_or_initialize_by(name: 'color')
color.label = 'Color'
color.kind = 'color_swatch'
color.save!

# Condition — new / refurbished / used. An option type rather than a column
# because that is exactly what it is: an axis that splits a product into
# variants, which hands it the whole option machinery for free (label
# kinds, positions, storefront pickers and facets) and gives a marketplace a
# new buy box and a used buy box on the same listing at no extra cost
# (docs/plans/6.0-multi-vendor-marketplace.md, Decision 11).
#
# Sample data, not a seed: nothing in core keys on the word "condition" — the
# buy box groups by whatever option values it is given — so a store that
# sells only new goods should not find this on a fresh install. A marketplace
# that wants its sellers to describe condition the same way loads it, or
# creates its own.
condition = Spree::OptionType.find_or_initialize_by(name: 'condition')
condition.label = 'Condition'
condition.kind = 'buttons'
condition.filterable = true
condition.save!

%w[new refurbished used].each_with_index do |value, index|
  next if condition.option_values.exists?(name: value)

  condition.option_values.create!(name: value, label: value.capitalize, position: index + 1)
end
