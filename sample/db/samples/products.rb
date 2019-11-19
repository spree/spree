require 'csv'

Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('shipping_categories')
Spree::Sample.load_sample('option_types')
Spree::Sample.load_sample('taxons')

default_shipping_category = Spree::ShippingCategory.find_by!(name: 'Default')
clothing_tax_category = Spree::TaxCategory.find_by!(name: 'Clothing')

Spree::Config[:currency] = 'USD'

color = Spree::OptionType.find_by!(name: 'color')
size = Spree::OptionType.find_by!(name: 'size')

PRODUCTS = CSV.read(File.join(__dir__, 'variants.csv')).map do |(parent_name, taxon_name, product_name, _color_name)|
  [parent_name, taxon_name, product_name]
end.uniq

PRODUCTS.each do |(parent_name, taxon_name, product_name)|
  parent = Spree::Taxon.find_by!(name: parent_name)
  taxon = parent.children.find_by!(name: taxon_name)
  taxon.products.where(name: product_name.titleize).first_or_create! do |product|
    product.price = rand(10...100) + 0.99
    product.description = FFaker::Lorem.paragraph
    product.available_on = Time.zone.now
    product.option_types = [color, size]
    product.shipping_category = default_shipping_category
    product.tax_category = clothing_tax_category
    product.sku = "#{product_name.delete(' ')}_#{product.price}"
    parent.products << product
  end
end

["Bestsellers", "New", "Trending", "Streetstyle", "Summer Sale"].each do |taxon_name|
  Spree::Taxon.find_by!(name: taxon_name).products << Spree::Product.all.sample(30)
end
