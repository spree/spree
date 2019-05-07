object false
child(@stock_movements => :stock_movements) do
  extends 'spree/api/v1/stock_movements/show'
end
node(:count) { @stock_movements.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @stock_movements.total_pages }
