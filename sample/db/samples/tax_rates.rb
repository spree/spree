Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('zones')

ukraine = Spree::Zone.find_by!(name: 'Україна')
clothing = Spree::TaxCategory.find_by!(name: 'Одяг')

Spree::TaxRate.where(
  name: 'Україна',
  zone: ukraine,
  amount: 0.1,
  tax_category: clothing
).first_or_create! do |tax_rate|
  tax_rate.calculator = Spree::Calculator::DefaultTax.create!
end
