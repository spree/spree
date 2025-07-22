require 'csv'

Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('option_types')
Spree::Sample.load_sample('products')

color_option_type = Spree::OptionType.find_by!(name: 'color')
size_option_type = Spree::OptionType.find_by!(name: 'size')

VARIANTS = CSV.read(File.join(__dir__, 'variants.csv'))

color_option_values = color_option_type.option_values.to_a
size_option_values = size_option_type.option_values.to_a

clothing_tax_category = Spree::TaxCategory.find_or_create_by!(name: 'Clothing')

VARIANTS.each do |(parent_name, taxon_name, product_name, color_name)|
  color = color_option_values.find { |c| c.name == color_name }

  product = Spree::Product.find_by!(name: product_name.titleize)

  size_option_values.each do |size|
    sku = "#{product.name.parameterize}-#{size.name.parameterize}-#{color.name.parameterize}".upcase

    variant = product.variants.find_or_initialize_by(sku: sku) do |variant|
      variant.cost_price = product.price
      variant.option_values = [color, size]
      variant.sku = sku
      variant.tax_category = clothing_tax_category
      variant.track_inventory = true
    end
    variant.save!
  end
end
