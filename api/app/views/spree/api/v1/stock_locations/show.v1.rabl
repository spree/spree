object @stock_location
attributes *stock_location_attributes
child(:country) do |address|
  attributes *country_attributes
end
child(:state) do |address|
  attributes *state_attributes
end
