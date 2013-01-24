object false
if @country
  node(:states_required) { @country.states_required }
end

child(@states => :states) do
  attributes *state_attributes
end

if @states.respond_to?(:num_pages)
  node(:count) { @states.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @states.num_pages }
end
