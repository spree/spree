object false

node(:count) { @shipments.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @shipments.total_pages }

child(@shipments => :shipments) do
  extends 'spree/api/v1/shipments/big'
end
