north_america = Spree::Zone.find_by!(name: 'North America')
clothing = Spree::TaxCategory.find_by!(name: 'Clothing')

Spree::TaxRate.where(
  name: 'North America',
  zone: north_america,
  amount: 0.05,
  tax_category: clothing
).first_or_create! do |tax_rate|
  tax_rate.calculator = Spree::Calculator::DefaultTax.create!
end
