object false
child(@orders) do
  extends "spree/api/v1/orders/show"
end
node(:count) { @orders.total_count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @orders.num_pages }
