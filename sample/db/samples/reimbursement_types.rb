reasons = [
  ['Exchange', 'Spree::ReimbursementType::Exchange'],
  ['Original payment', 'Spree::ReimbursementType::OriginalPayment'],
  ['Store credit', 'Spree::ReimbursementType::StoreCredit'],
].map do |name, kind|
  { name: name, type: kind }
end

reasons.each do |reason|
  Spree::ReimbursementType.find_or_create_by!(name: reason[:name], type: reason[:type])
end
