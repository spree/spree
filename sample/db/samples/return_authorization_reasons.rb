reasons = [
  'Better price available',
  'Missed estimated delivery date',
  'Missing parts or accessories',
  'Damaged/Defective',
  'Different from what was ordered',
  'Different from description',
  'No longer needed/wanted',
  'Accidental order',
  'Unauthorized purchase',
].map do |name|
  {name: name}
end

if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
  Spree::ReturnAuthorizationReason.insert_all(reasons)
else
  Spree::ReturnAuthorizationReason.upsert_all(reasons, unique_by: :name)
end
