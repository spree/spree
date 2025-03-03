require 'csv'

Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('option_types')
Spree::Sample.load_sample('taxons')

default_shipping_category = Spree::ShippingCategory.find_or_create_by!(name: 'Default')
clothing_tax_category = Spree::TaxCategory.find_or_create_by!(name: 'Clothing')

color_option_type = Spree::OptionType.find_by!(name: 'color')
size_option_type = Spree::OptionType.find_by!(name: 'size')

PRODUCTS = CSV.read(File.join(__dir__, 'variants.csv'))

taxons = Spree::Taxon.includes(:children).all

PRODUCTS.each do |(parent_name, taxon_name, product_name, color_name)|
  parent = taxons.find { |taxon| taxon.name == parent_name }
  taxon = parent.children.find { |child| child.name == taxon_name }

  sleep(0.1) # to avoid DB lock

  product = Spree::Product.find_or_initialize_by(name: product_name.titleize) do |product|
    product.price = rand(10...100) + 0.99
    product.description = FFaker::Lorem.paragraph
    product.available_on = Time.zone.now
    product.status = 'active'
    product.option_types = [color_option_type, size_option_type]
    product.shipping_category = default_shipping_category
    product.tax_category = clothing_tax_category
    product.taxons = [taxon]
  end
  product.save!
end

store_ids = Spree::Store.ids
product_ids = Spree::Product.ids

store_ids.each do |store_id|
  Spree::StoreProduct.upsert_all(
    product_ids.map { |product_id| { store_id: store_id, product_id: product_id } },
    unique_by: [:store_id, :product_id]
  )
end
