%w[warranty capacity voltage wattage runtime room_coverage noise_level connectivity].each do |key|
  Spree::MetafieldDefinition.find_or_create_by!(
    namespace: 'custom',
    key: key,
    resource_type: 'Spree::Product'
  )
end
