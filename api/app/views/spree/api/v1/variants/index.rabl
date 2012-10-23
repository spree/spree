object false
node(:count) { @variants.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @variants.num_pages }

child(@variants => :variants) do
  attributes *variant_attributes
  child(:option_values => :option_values) { attributes *option_value_attributes }
end
