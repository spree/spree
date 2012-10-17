object @country
attributes :id, :iso_name, :iso, :iso3, :name, :numcode
child :states => :states do
  attributes :id, :name, :abbr, :country_id
end