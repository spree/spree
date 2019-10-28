require 'csv'

Spree::Sample.load_sample('taxonomies')

CHILDREN_TAXON_NAMES = CSV.read(File.join(__dir__, 'variants.csv')).map do |(parent_name, taxon_name, _product_name, _color_name)|
  [parent_name, taxon_name]
end.uniq

TAXON_NAMES = CHILDREN_TAXON_NAMES.map { |(parent_name, taxon_name)| parent_name }

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

['Bestsellers', 'Trending', 'Streetstyle', 'Summer Sale'].each do |taxon_name|
  taxon = categories_taxon.children.where(name: taxon_name).first_or_create!
  taxon.permalink = taxon.permalink.gsub('categories/', '')
  taxon.taxonomy = categories
  taxon.save!
end
