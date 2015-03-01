object false
node(:count) { @taxons.count }
node(:total_count) { @taxons.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:per_page) { params[:per_page] || Kaminari.config.default_per_page }
node(:pages) { @taxons.num_pages }
child @taxons => :taxons do
  attributes *taxon_attributes
  unless params[:without_children]
    extends "spree/api/taxons/taxons"
  end
end
