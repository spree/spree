module Spree
  class ZoneSerializer < ActiveModel::Serializer
    attributes :id, :name
    
    has_many :zone_members
  end
end