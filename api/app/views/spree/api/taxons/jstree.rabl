collection @taxon.children, :object_root => false
node(:data) { |taxon| taxon.name }
node(:attr) do |taxon|
  { :id => taxon.id,
    :name => taxon.name
  }
end
node(:state) { "closed" }
