Spree::Sample.load_sample('stores')

taxonomies = [
  {
    name: I18n.t('spree.taxonomy_categories_name'),
    store: Spree::Store.default
  }
]

taxonomies.each do |taxonomy_attrs|
  Spree::Taxonomy.where(taxonomy_attrs).first_or_create!
end
