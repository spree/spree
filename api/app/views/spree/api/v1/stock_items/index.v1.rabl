object false
child(@stock_items => :stock_items) do
  extends 'spree/api/v1/stock_items/show'
end
node(:count) { @stock_items.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @stock_items.total_pages }
