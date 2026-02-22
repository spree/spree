%w[manufacturer material fit].each do |key|
  Spree::MetafieldDefinition.find_or_create_by!(
    namespace: 'properties',
    key: key,
    resource_type: 'Spree::Product'
  )
end
