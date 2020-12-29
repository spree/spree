object false
node(:count) { @taxons.count }
node(:total_count) { @taxons.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:per_page) { params[:per_page].try(:to_i) || Kaminari.config.default_per_page }
node(:pages) { @taxons.total_pages }
child @taxons => :taxons do
  attributes *taxon_attributes
  extends 'spree/api/v1/taxons/taxons' unless params[:without_children]
end
