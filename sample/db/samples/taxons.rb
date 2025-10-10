require 'csv'

ADDITIONAL_TAXONS = ['Bestsellers', 'Trending', 'Streetstyle', 'Summer Sale'].freeze

SPECIAL_TAXONS = { 'New Collection': "Summer #{Date.today.year}", 'Special Offers': '30% Off' }.freeze

CHILDREN_TAXON_NAMES = CSV.read(File.join(__dir__, 'variants.csv')).map do |(parent_name, taxon_name, _product_name, _color_name)|
  [parent_name, taxon_name]
end.uniq

TAXON_NAMES = CHILDREN_TAXON_NAMES.map { |(parent_name, taxon_name)| parent_name }

categories = Spree::Taxonomy.find_by!(name: I18n.t('spree.taxonomy_categories_name'))
categories_taxon = Spree::Taxon.where(name: I18n.t('spree.taxonomy_categories_name')).first_or_create!

TAXON_NAMES.each do |taxon_name|
  taxon =
    if not categories_taxon.children.where(name: taxon_name).exists?
      Spree::Taxon.create!(name: taxon_name, parent_id: categories_taxon.id, taxonomy: categories)
    else
      categories_taxon.children.where(name: taxon_name).first
    end
  taxon.taxonomy = categories
  taxon.save!
end

CHILDREN_TAXON_NAMES.each do |(parent_name, taxon_name)|
  parent = Spree::Taxon.where(name: parent_name).first
  taxon =
    if parent.children.where(name: taxon_name).any?
      parent.children.where(name: taxon_name).first
    else
      Spree::Taxon.create!(name: taxon_name, parent_id: parent.id, taxonomy: categories)
    end
  taxon.taxonomy = categories
  taxon.save!
end

taxon =
  if categories_taxon.children.where(name: 'New').any?
    categories_taxon.children.where(name: 'New').first
  else
    Spree::Taxon.create!(name: 'New', parent_id: categories_taxon.id, taxonomy: categories)
  end
taxon.taxonomy = categories
taxon.save!

ADDITIONAL_TAXONS.each do |taxon_name|
  taxon =
    if categories_taxon.children.where(name: taxon_name).any?
      categories_taxon.children.where(name: taxon_name).first
    else
      Spree::Taxon.create!(name: taxon_name, parent_id: categories_taxon.id, taxonomy: categories)
    end
  taxon.taxonomy = categories
  taxon.save!
end

SPECIAL_TAXONS.each do |parent_name, taxon_name|
  parent =
    if categories_taxon.children.where(name: parent_name.to_s).any?
      categories_taxon.children.where(name: parent_name.to_s).first
    else
      Spree::Taxon.create!(name: parent_name.to_s, parent_id: categories_taxon.id, taxonomy: categories)
    end
  parent.taxonomy = categories
  parent.save!

  taxon =
    if parent.children.where(name: taxon_name).any?
      parent.children.where(name: taxon_name).first
    else
      Spree::Taxon.create!(name: taxon_name, parent_id: parent.id, taxonomy: categories)
    end

  taxon.taxonomy = categories
  taxon.save!
end
