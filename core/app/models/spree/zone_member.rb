module Spree
  class ZoneMember < Spree::Base
    belongs_to :zone, counter_cache: true, inverse_of: :zone_members
    belongs_to :zoneable, polymorphic: true
  end
end
