object @stock_location
attributes *stock_location_attributes
child(:country) do |_address|
  attributes *country_attributes
end
child(:state) do |_address|
  attributes *state_attributes
end
