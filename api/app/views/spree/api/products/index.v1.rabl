object false
node(:count) { @products.count }
node(:total_count) { @products.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @products.num_pages }
node(:per_page) { params[:per_page] || Kaminari.config.default_per_page }
child(@products => :products) do
  extends "spree/api/products/show"
end
