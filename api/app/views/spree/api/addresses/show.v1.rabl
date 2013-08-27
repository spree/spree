object @address
attributes *address_attributes

child(:country) do |address|
  attributes *country_attributes
end
child(:state) do |address|
  attributes *state_attributes
end
