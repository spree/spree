Given /^the custom taxons exist$/ do

  taxonomy = Taxonomy.find_by_name('Brand')
  root = taxonomy.root
  ["Ruby on Rails", "Ruby", "Apache"].each do |name|
    taxonomy.taxons.create(:name => name, :parent_id => root.id)
  end

  taxonomy = Taxonomy.find_by_name('Categories')
  root = taxonomy.root
  ["Clothing", "Bags", "Mugs"].each do |name|
    taxonomy.taxons.create(:name => name, :parent_id => root.id)
  end

end
