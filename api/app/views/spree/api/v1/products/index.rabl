object false
node(:count) { @products.count }
node(:total_count) { @products.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @products.num_pages }
child(@products => :products) do
  extends "spree/api/v1/products/show"
end

