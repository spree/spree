object false
child(@taxonomies => :taxonomies) do
  extends 'spree/api/v1/taxonomies/show'
end
node(:count) { @taxonomies.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @taxonomies.total_pages }
