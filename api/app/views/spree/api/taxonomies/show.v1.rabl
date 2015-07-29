object @taxonomy

if params[:set].eql?('nested')
  extends 'spree/api/taxonomies/nested'
else
  attributes *taxonomy_attributes

  child root: :root do
    attributes *taxon_attributes

    child children: :taxons do
      attributes *taxon_attributes
    end
  end
end
