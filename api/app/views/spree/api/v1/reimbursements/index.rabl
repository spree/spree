object false
child(@collection => :reimbursements) do
  attributes *reimbursement_attributes
end
node(:count) { @collection.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @collection.total_pages }
