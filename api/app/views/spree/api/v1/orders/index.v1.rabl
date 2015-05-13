object false
child(@orders => :orders) do
  extends "spree/api/v1/orders/order"
end
node(:count) { @orders.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @orders.num_pages }
