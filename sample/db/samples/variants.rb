require 'csv'

Spree::Sample.load_sample('option_values')
Spree::Sample.load_sample('products')
Spree::Sample.load_sample('tax_categories')

VARIANTS = CSV.read(File.join(__dir__, 'variants.csv'))

clothing_tax_category = Spree::TaxCategory.find_or_create_by!(name: 'Одяг')
color_option_values = Spree::OptionType.find_by!(name: 'color').option_values
length_option_values = Spree::OptionType.find_by!(name: 'length').option_values
size_option_values = Spree::OptionType.find_by!(name: 'size').option_values

def image(variant)
  picture = Spree::Image.new
  filename = "#{variant.join(',').downcase}.jpg"
  file = File.open(File.join(__dir__, "images", "product_variants", filename))
  picture.attachment.attach(io: file, filename:, content_type: 'image/jpg')
  picture
end

VARIANTS.each do |(parent_name, taxon_name, product_name, color_name)|
  parent = Spree::Taxon.find_by!(name: parent_name)
  taxon = parent.children.find_by!(name: taxon_name)
  product = Spree::Product.find_by!(name: product_name.titleize)
  color = color_option_values.find_by!(name: color_name)

  size_option_values.each do |size|
    if parent_name == 'Жінки' and %w[Сукні Спідниці].include?(taxon_name)
      length_option_values.each do |length|
        option_values = [color, length, size]
        product.variants.first_or_create! do |variant|
          variant.cost_price = product.price
          variant.option_values = option_values
          variant.sku = product.sku + '_' + option_values.map(&:name).join('_')
          variant.tax_category = clothing_tax_category
          variant.images << image([parent_name, taxon_name, product_name, color_name]) if variant.images.empty?
        end
      end
    else
      option_values = [color, size]
      product.variants.first_or_create! do |variant|
        variant.cost_price = product.price
        variant.option_values = option_values
        variant.sku = product.sku + '_' + option_values.map(&:name).join('_')
        variant.tax_category = clothing_tax_category
        variant.images << image([parent_name, taxon_name, product_name, color_name]) if variant.images.empty?
      end
    end
  end
end
