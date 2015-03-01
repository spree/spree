object false
child(@taxonomies => :taxonomies) do
  extends "spree/api/taxonomies/show"
end
node(:count) { @taxonomies.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @taxonomies.num_pages }
