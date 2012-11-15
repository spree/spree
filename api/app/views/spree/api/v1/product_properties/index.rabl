object false
child(@product_properties => :product_properties) do
  attributes *product_property_attributes 
end
node(:count) { @product_properties.count }
node(:current_page) { params[:page] || 1 }
node(:pages) { @product_properties.num_pages }
