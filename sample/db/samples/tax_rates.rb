Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('zones')

california = Spree::Zone.find_by!(name: 'California Tax')
clothing = Spree::TaxCategory.find_by!(name: 'Clothing')

Spree::TaxRate.where(
  name: 'California',
  zone: california,
  amount: 0.1,
  tax_category: clothing
).first_or_create! do |tax_rate|
  tax_rate.calculator = Spree::Calculator::DefaultTax.create!
end
