taxonomies = [
  { name: "Categories" },
  { name: "Brand" }
]

taxonomies.each do |taxonomy_attrs|
  Spree::Taxonomy.where(taxonomy_attrs).first_or_create!
end
