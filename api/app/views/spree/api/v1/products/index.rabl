object false
child(@products) do
  extends "spree/api/v1/products/show"
end
node(:count) { @products.total_count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @products.num_pages }

