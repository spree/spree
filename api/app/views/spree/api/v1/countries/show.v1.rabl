object @country
attributes *country_attributes
child states: :states do
  attributes :id, :name, :abbr, :country_id
end
