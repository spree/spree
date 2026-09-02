store = Spree::Store.default

%w[warranty capacity voltage wattage runtime room_coverage noise_level connectivity].each do |key|
  store.custom_field_definitions.find_or_create_by!(
    namespace: 'custom',
    key: key,
    resource_type: 'Spree::Product'
  )
end
