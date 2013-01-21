object false
child(@states => :states) do
  attributes *state_attributes
end
node(:count) { @states.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @states.num_pages }
