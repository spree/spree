object false
child(@stock_movements => :stock_movements) do
  extends 'spree/api/stock_movements/show'
end
node(:count) { @stock_movements.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @stock_movements.num_pages }
