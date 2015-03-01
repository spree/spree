object false

node(:count) { @shipments.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @shipments.num_pages }

child(@shipments => :shipments) do
  extends "spree/api/shipments/big"
end
