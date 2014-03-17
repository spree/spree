object @zone
attributes :id, :name, :description

child :zone_members => :zone_members do
  attributes :id, :country_code, :region_code
end
