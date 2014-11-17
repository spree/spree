object false

child(@store_credit_events => :store_credit_events) do
  attributes *store_credit_history_attributes
  node(:order_number) { |event| event.order.try(:number) }
end

node(:count) { @store_credit_events.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @store_credit_events.num_pages }
