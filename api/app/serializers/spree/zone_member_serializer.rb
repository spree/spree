module Spree
  class ZoneMemberSerializer < Spree::BaseSerializer
    attributes :id, :name, :zoneable_type, :zoneable_id
  end
end
