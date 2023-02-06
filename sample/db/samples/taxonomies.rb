Spree::Sample.load_sample('stores')

taxonomies = [
  {
    name: I18n.t('spree.taxonomy_categories_name'),
    store: Spree::Store.default
  }
]

taxonomies.each do |taxonomy_attrs|
  if Spree::Taxonomy.where(taxonomy_attrs).any?
    Spree::Taxonomy.where(taxonomy_attrs).first
  else
    Spree::Taxonomy.create!(taxonomy_attrs)
  end
end
