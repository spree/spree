object @taxonomy

if params[:set] == 'nested'
  extends 'spree/api/v1/taxonomies/nested'
else
  attributes *taxonomy_attributes

  child root: :root do
    attributes *taxon_attributes

    child children: :taxons do
      attributes *taxon_attributes
    end
  end
end
