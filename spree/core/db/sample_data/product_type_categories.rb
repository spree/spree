# Links each product type to the category its products live in, so a merchant
# creating a new product of that type gets the category suggested for free.
#
# Runs after the product import because the import is what creates the
# categories — before it there is nothing to link to. Seeding is additive and
# only applies to products created from here on, so linking after the fact
# changes nothing about the imported catalog.
store = Spree::Store.default

categories_by_type = {
  'Kitchen Appliance' => 'Kitchen',
  'Air Treatment' => 'Air & Climate',
  'Garment Care' => 'Garment Care',
  'Vacuum Cleaner' => 'Floor Care',
  'Hair Styling' => 'Personal Care',
  'Grooming' => 'Personal Care'
}

categories_by_type.each do |product_type_name, category_name|
  product_type = store.product_types.find_by(name: product_type_name)
  next if product_type.nil?

  category = store.categories.find_by(name: category_name)
  next if category.nil? || product_type.categories.include?(category)

  product_type.categories << category
end
