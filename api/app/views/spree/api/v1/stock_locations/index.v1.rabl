object false
child(@stock_locations => :stock_locations) do
  extends 'spree/api/v1/stock_locations/show'
end
node(:count) { @stock_locations.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @stock_locations.num_pages }
