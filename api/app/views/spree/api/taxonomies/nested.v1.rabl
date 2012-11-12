attributes *taxonomy_attributes

child :root => :root do
  attributes *taxon_attributes

  child :children => :taxons do
    attributes *taxon_attributes

    extends "spree/api/taxons/taxons"
  end
end
