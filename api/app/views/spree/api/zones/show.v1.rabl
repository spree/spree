object @zone
attributes :id, :name, :description

child :zone_members => :zone_members do
  attributes :id, :name, :zoneable_type, :zoneable_id
end
