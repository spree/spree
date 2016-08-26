object false
child(@countries => :countries) do
  attributes *country_attributes
end
node(:count) { @countries.count }
node(:current_page) { params[:page].try(:to_i) || 1 }
node(:pages) { @countries.total_pages }
