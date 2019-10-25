Spree::Sample.load_sample('taxonomies')

TAXON_NAMES = %w(Men Women Sportswear)
CHILDREN_TAXON_NAMES = [
  ["Men", "Shirts"],
  ["Men", "T-shirts"],
  ["Men", "Sweaters"],
  ["Men", "Jackets and Coats"],
  ["Women", "Skirts"],
  ["Women", "Dresses"],
  ["Women", "Shirts and Blouses"],
  ["Women", "Sweaters"],
  ["Women", "Tops and T-shirts"],
  ["Women", "Jackets and Coats"],
  ["Sportswear", "Tops"],
  ["Sportswear", "Sweatshirts"],
  ["Sportswear", "Pants"]
]

categories = Spree::Taxonomy.find_by!(name: I18n.t('spree.taxonomy_categories_name'))
categories_taxon = Spree::Taxon.where(name: I18n.t('spree.taxonomy_categories_name')).first_or_create!

TAXON_NAMES.each do |taxon_name|
  taxon = categories_taxon.children.where(name: taxon_name).first_or_create!
  taxon.permalink = taxon.permalink.gsub('categories/', '')
  taxon.taxonomy = categories
  taxon.save!
end

CHILDREN_TAXON_NAMES.each do |(parent_name, taxon_name)|
  parent = Spree::Taxon.where(name: parent_name).first
  taxon = parent.children.where(name: taxon_name).first_or_create!
  taxon.permalink = taxon.permalink.gsub('categories/', '')
  taxon.taxonomy = categories
  taxon.save!
end

taxon = categories_taxon.children.where(name: 'New', permalink: 'newest').first_or_create!
taxon.permalink = taxon.permalink.gsub('categories/', '')
taxon.taxonomy = categories
taxon.save!

["Bestsellers", "Trending", "Streetstyle", "Summer Sale"].each do |taxon_name|
  taxon = categories_taxon.children.where(name: taxon_name).first_or_create!
  taxon.permalink = taxon.permalink.gsub('categories/', '')
  taxon.taxonomy = categories
  taxon.save!
end
