node do |t|
  child t.children => :taxons do
    attributes *taxon_attributes

    extends "spree/api/taxons/taxons"
  end
end
