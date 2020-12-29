object false
child(@payments => :payments) do
  attributes *payment_attributes
end
node(:count) { @payments.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @payments.total_pages }
