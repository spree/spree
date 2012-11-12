object false
node(:count) { @variants.count }
node(:total_count) { @variants.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @variants.num_pages }

child(@variants => :variants) do
  attributes *variant_attributes
  child(:option_values => :option_values) { attributes *option_value_attributes }
  child(:images => :images) { attributes *image_attributes }
end
