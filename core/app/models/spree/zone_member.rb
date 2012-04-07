module Spree
  class ZoneMember < ActiveRecord::Base
    belongs_to :zone
    belongs_to :zoneable, :polymorphic => true

    attr_accessible :zone, :zone_id, :zoneable, :zoneable_id, :zoneable_type

    def name
      return nil if zoneable.nil?
      zoneable.name
    end
  end
end
