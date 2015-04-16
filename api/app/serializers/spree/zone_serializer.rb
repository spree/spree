module Spree
  class ZoneSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.zone_attributes
    attributes :id, :name

    has_many :zone_members
  end
end
