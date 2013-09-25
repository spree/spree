object false
child(@payments => :payments) do
  attributes *payment_attributes
  node(:display_amount) { |payment| payment.display_amount.to_s }
end
node(:count) { @payments.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @payments.num_pages }
