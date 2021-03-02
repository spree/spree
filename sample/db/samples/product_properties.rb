Spree::Sample.load_sample('taxons')
Spree::Sample.load_sample('products')

men_tshirts_properties = [
  {
    'manufacturer' => 'Wilson',
    'brand' => 'Wannabe Sports',
    'model' => 'JK1002',
    'shirt_type' => 'Baseball Jersey',
    'sleeve_type' => 'Long',
    'material' => '100% cotton',
    'fit' => 'Loose',
    'gender' => 'Men\'s'
  },
  {
    'manufacturer' => 'Jerseys',
    'brand' => 'Conditioned',
    'model' => 'TL9002',
    'shirt_type' => 'Ringer T',
    'sleeve_type' => 'Short',
    'material' => '100% Vellum',
    'fit' => 'Loose',
    'gender' => 'Men\'s'
  },
  {
    'manufacturer' => 'Wilson',
    'brand' => 'Wannabe Sports',
    'model' => 'JK1002',
    'shirt_type' => 'Baseball Jersey',
    'sleeve_type' => 'Long',
    'material' => '100% cotton',
    'fit' => 'Loose',
    'gender' => 'Men\'s'
  },
  {
    'manufacturer' => 'Jerseys',
    'brand' => 'Conditioned',
    'model' => 'TL9002',
    'shirt_type' => 'Ringer T',
    'sleeve_type' => 'Short',
    'material' => '100% Vellum',
    'fit' => 'Loose',
    'gender' => 'Men\'s'
  }
]

Spree::Taxon.find_by!(name: 'Men').children.find_by!(name: 'T-shirts').products.each do |product|
  men_tshirts_properties.sample.each do |prop_name, prop_value|
    product.set_property(prop_name, prop_value, prop_name.gsub('_', ' ').capitalize)
  end
end

women_tshirts_properties = [
  {
    'manufacturer' => 'Jerseys',
    'brand' => 'Resiliance',
    'model' => 'TL174',
    'shirt_type' => 'Jr. Spaghetti T',
    'sleeve_type' => 'None',
    'material' => '90% Cotton, 10% Nylon',
    'fit' => 'Form',
    'gender' => 'Women\'s'
  },
  {
    'manufacturer' => 'Jerseys',
    'brand' => 'Resiliance',
    'model' => 'TL174',
    'shirt_type' => 'Jr. Spaghetti T',
    'sleeve_type' => 'None',
    'material' => '90% Cotton, 10% Nylon',
    'fit' => 'Form',
    'gender' => 'Women\'s'
  }
]

Spree::Taxon.find_by!(name: 'Women').children.find_by!(name: 'Tops and T-shirts').products.each do |product|
  women_tshirts_properties.sample.each do |prop_name, prop_value|
    product.set_property(prop_name, prop_value, prop_name.gsub('_', ' ').capitalize)
  end
end

properties = {
  manufacturers: %w[Wilson Jerseys Wannabe Resiliance Conditioned],
  brands: %w[Alpha Beta Gamma Delta Theta Epsilon Zeta],
  materials: ['90% Cotton 10% Elastan', '50% Cotton 50% Elastan', '10% Cotton 90% Elastan'],
  fits: %w[Form Lose]
}

t_shirts_taxon = Spree::Taxon.where(name: ['T-shirts', 'Tops and T-shirts'])

Spree::Product.all.each do |product|
  product.set_property(:type, product.taxons.first.name)
  product.set_property(:collection, product.taxons.first.name)

  next if product.taxons.include?(t_shirts_taxon)

  product.set_property(:manufacturer, properties[:manufacturers].sample)
  product.set_property(:brand, properties[:brands].sample)
  product.set_property(:material, properties[:materials].sample)
  product.set_property(:fit, properties[:fits].sample)
  product.set_property(:gender, (product.taxons.pluck(:name).include?('Men') ? 'Men\'s' : 'Women\'s'))
  product.set_property(:model, product.sku)
end
