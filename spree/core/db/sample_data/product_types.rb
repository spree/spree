# Six product types covering the demo catalog, each with a different schema so
# the feature is visible rather than nominal: every type shares the electrical
# basics (wattage, voltage, warranty) and then adds the fields its category
# actually needs — capacity for kitchen appliances, runtime for cordless
# grooming, room coverage and noise for air treatment.
#
# Runs before the product import, which resolves the CSV's product_type column
# by name. Without this file the import would still create the types, but they
# would carry no option types or custom field schema.
#
# Categories are attached afterwards by product_type_categories.rb — the import
# is what creates them, so there is nothing to link to at this point.
store = Spree::Store.default

color_option_type = Spree::OptionType.find_by(name: 'color')

definitions = Spree::MetafieldDefinition.where(
  namespace: 'custom',
  resource_type: 'Spree::Product'
).index_by(&:key)

# required: every product of the type must fill it before it can be activated.
# optional: shown on the form, filled where it applies.
product_types = [
  {
    name: 'Kitchen Appliance',
    required_fields: %w[wattage voltage warranty],
    optional_fields: %w[capacity]
  },
  {
    name: 'Air Treatment',
    required_fields: %w[wattage voltage warranty room_coverage],
    optional_fields: %w[capacity noise_level connectivity]
  },
  {
    name: 'Garment Care',
    required_fields: %w[wattage voltage warranty],
    optional_fields: %w[capacity]
  },
  {
    name: 'Vacuum Cleaner',
    required_fields: %w[wattage voltage warranty],
    optional_fields: %w[runtime connectivity]
  },
  {
    name: 'Hair Styling',
    required_fields: %w[wattage voltage warranty],
    optional_fields: []
  },
  {
    name: 'Grooming',
    required_fields: %w[wattage voltage warranty runtime],
    optional_fields: []
  }
]

product_types.each do |attributes|
  product_type = store.product_types.find_or_initialize_by(name: attributes[:name])
  product_type.fulfillment_types = ['shipping']
  product_type.save!

  # Seeded onto products created with this type — every demo product varies by color.
  if color_option_type.present? && product_type.option_types.exclude?(color_option_type)
    product_type.option_types << color_option_type
  end

  attributes[:required_fields].each_with_index do |key, index|
    definition = definitions[key]
    next if definition.nil?

    join = product_type.product_type_custom_field_definitions.
           find_or_initialize_by(custom_field_definition_id: definition.id)
    join.required = true
    join.sort_order = index
    join.save!
  end

  attributes[:optional_fields].each_with_index do |key, index|
    definition = definitions[key]
    next if definition.nil?

    join = product_type.product_type_custom_field_definitions.
           find_or_initialize_by(custom_field_definition_id: definition.id)
    join.required = false
    join.sort_order = attributes[:required_fields].length + index
    join.save!
  end
end
