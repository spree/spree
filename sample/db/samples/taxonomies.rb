taxonomies = [
  { name: I18n.t('spree.taxonomy_brands_name') },
  { name: "Brand" }
]

taxonomies.each do |taxonomy_attrs|
  Spree::Taxonomy.where(taxonomy_attrs).first_or_create!
end
