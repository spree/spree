module Spree
  class ZoneSerializer < Spree::BaseSerializer
    attributes :id, :name, :description

    has_many :zone_members
  end
end
