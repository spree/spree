require 'csv'

Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('shipping_categories')
Spree::Sample.load_sample('option_types')
Spree::Sample.load_sample('taxons')

default_shipping_category = Spree::ShippingCategory.find_by!(name: 'Default')
clothing_tax_category = Spree::TaxCategory.find_by!(name: 'Clothing')

Spree::Config[:currency] = 'USD'

color = Spree::OptionType.find_by!(name: 'color')
length = Spree::OptionType.find_by!(name: 'length')
size = Spree::OptionType.find_by!(name: 'size')

PRODUCTS = CSV.read(File.join(__dir__, 'variants.csv')).map do |(parent_name, taxon_name, product_name, _color_name)|
  [parent_name, taxon_name, product_name]
end.uniq

PRODUCTS.each do |(parent_name, taxon_name, product_name)|
  parent = Spree::Taxon.find_by!(name: parent_name)
  taxon = parent.children.find_by!(name: taxon_name)
  Spree::Product.where(name: product_name.titleize).first_or_create! do |product|
    product.price = rand(10...100) + 0.99
    product.description = FFaker::Lorem.paragraph
    product.available_on = Time.zone.now
    if parent_name == 'Women' and %w[Dresses Skirts].include?(taxon_name)
      product.option_types = [color, length, size]
    else
      product.option_types = [color, size]
    end
    product.shipping_category = default_shipping_category
    product.tax_category = clothing_tax_category
    product.sku = [taxon_name.delete(' '), product_name.delete(' '), product.price].join('_')
    product.taxons << parent unless product.taxons.include?(parent)
    product.taxons << taxon unless product.taxons.include?(taxon)
  end
end

Spree::Taxon.where(name: ['Bestsellers', 'New', 'Trending', 'Streetstyle', 'Summer Sale']).each do |taxon|
  next if taxon.products.any?

  taxon.products << Spree::Product.all.sample(30)
end
