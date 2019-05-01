object @address
cache [I18n.locale, root_object]
attributes *address_attributes

child(:country) do |_address|
  attributes *country_attributes
end
child(:state) do |_address|
  attributes *state_attributes
end
