taxonomies = [
  { :name => "Categories" },
  { :name => "Brand" }
]

taxonomies.each do |taxonomy_attrs|
  Spree::Taxonomy.create!(taxonomy_attrs)
end
