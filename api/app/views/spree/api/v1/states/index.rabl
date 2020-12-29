object false
node(:states_required) { @country.states_required } if @country

child(@states => :states) do
  attributes *state_attributes
end

if @states.respond_to?(:total_pages)
  node(:count) { @states.count }
  node(:current_page) { params[:page].try(:to_i) || 1 }
  node(:pages) { @states.total_pages }
end
