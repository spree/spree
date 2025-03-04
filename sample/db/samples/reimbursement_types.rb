reasons = [
  ['Exchange', 'Spree::ReimbursementType::Exchange'],
  ['Original payment', 'Spree::ReimbursementType::OriginalPayment'],
  ['Store credit', 'Spree::ReimbursementType::StoreCredit'],
].map do |name, kind|
  { name: name, type: kind }
end

Spree::ReimbursementType.insert_all(reasons, unique_by: :name)
