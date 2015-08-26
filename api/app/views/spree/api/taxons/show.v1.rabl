object @taxon
attributes *taxon_attributes

child :children => :taxons do
  attributes *taxon_attributes
end
