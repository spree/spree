Spree::Sample.load_sample('taxonomies')
Spree::Sample.load_sample('products')

categories = Spree::Taxonomy.find_by!(name: I18n.t('spree.taxonomy_categories_name'))
brands = Spree::Taxonomy.find_by!(name: I18n.t('spree.taxonomy_brands_name'))

products = {
  ror_tote: 'Ruby on Rails Tote',
  ror_bag: 'Ruby on Rails Bag',
  ror_mug: 'Ruby on Rails Mug',
  ror_stein: 'Ruby on Rails Stein',
  ror_baseball_jersey: 'Ruby on Rails Baseball Jersey',
  ror_jr_spaghetti: 'Ruby on Rails Jr. Spaghetti',
  ror_ringer: 'Ruby on Rails Ringer T-Shirt',
  spree_stein: 'Spree Stein',
  spree_mug: 'Spree Mug',
  spree_ringer: 'Spree Ringer T-Shirt',
  spree_baseball_jersey: 'Spree Baseball Jersey',
  spree_tote: 'Spree Tote',
  spree_bag: 'Spree Bag',
  spree_jr_spaghetti: 'Spree Jr. Spaghetti',
  apache_baseball_jersey: 'Apache Baseball Jersey',
  ruby_baseball_jersey: 'Ruby Baseball Jersey'
}

products.each do |key, name|
  products[key] = Spree::Product.find_by!(name: name)
end

taxons = [
  {
    name: I18n.t('spree.taxonomy_categories_name'),
    taxonomy: categories,
    position: 0
  },
  {
    name: 'Bags',
    taxonomy: categories,
    parent: I18n.t('spree.taxonomy_categories_name'),
    position: 1,
    products: [
      products[:ror_tote],
      products[:ror_bag],
      products[:spree_tote],
      products[:spree_bag]
    ]
  },
  {
    name: 'Mugs',
    taxonomy: categories,
    parent: I18n.t('spree.taxonomy_categories_name'),
    position: 2,
    products: [
      products[:ror_mug],
      products[:ror_stein],
      products[:spree_stein],
      products[:spree_mug]
    ]
  },
  {
    name: 'Clothing',
    taxonomy: categories,
    parent: I18n.t('spree.taxonomy_categories_name')
  },
  {
    name: 'Shirts',
    taxonomy: categories,
    parent: 'Clothing',
    position: 0,
    products: [
      products[:ror_jr_spaghetti],
      products[:spree_jr_spaghetti]
    ]
  },
  {
    name: 'T-Shirts',
    taxonomy: categories,
    parent: 'Clothing',
    products: [
      products[:ror_baseball_jersey],
      products[:ror_ringer],
      products[:apache_baseball_jersey],
      products[:ruby_baseball_jersey],
      products[:spree_baseball_jersey],
      products[:spree_ringer]
    ],
    position: 0
  },
  {
    name: I18n.t('spree.taxonomy_brands_name'),
    taxonomy: brands
  },
  {
    name: 'Ruby',
    taxonomy: brands,
    parent: I18n.t('spree.taxonomy_brands_name'),
    products: [
      products[:ruby_baseball_jersey]
    ]
  },
  {
    name: 'Apache',
    taxonomy: brands,
    parent: I18n.t('spree.taxonomy_brands_name'),
    products: [
      products[:apache_baseball_jersey]
    ]
  },
  {
    name: 'Spree',
    taxonomy: brands,
    parent: I18n.t('spree.taxonomy_brands_name'),
    products: [
      products[:spree_stein],
      products[:spree_mug],
      products[:spree_ringer],
      products[:spree_baseball_jersey],
      products[:spree_tote],
      products[:spree_bag],
      products[:spree_jr_spaghetti]
    ]
  },
  {
    name: 'Rails',
    taxonomy: brands,
    parent: I18n.t('spree.taxonomy_brands_name'),
    products: [
      products[:ror_tote],
      products[:ror_bag],
      products[:ror_mug],
      products[:ror_stein],
      products[:ror_baseball_jersey],
      products[:ror_jr_spaghetti],
      products[:ror_ringer]
    ]
  }
]

taxons.each do |taxon_attrs|
  parent = Spree::Taxon.where(name: taxon_attrs[:parent]).first
  taxonomy = taxon_attrs[:taxonomy]

  taxon = Spree::Taxon.where(name: taxon_attrs[:name]).first_or_create!
  taxon.parent = parent
  taxon.taxonomy = taxonomy
  taxon.save
  taxon.products = taxon_attrs[:products] if taxon_attrs[:products]
end
