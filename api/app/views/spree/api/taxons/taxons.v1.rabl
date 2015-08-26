attributes *taxon_attributes

node :taxons do |t|
  t.children.map { |c| partial("spree/api/taxons/taxons", :object => c) }
end
