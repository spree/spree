[
  'Better price available',
  'Missed estimated delivery date',
  'Missing parts or accessories',
  'Damaged/Defective',
  'Different from what was ordered',
  'Different from description',
  'No longer needed/wanted',
  'Accidental order',
  'Unauthorized purchase',
].each do |name|
  Spree::ReturnAuthorizationReason.find_or_create_by!(name: name)
end
