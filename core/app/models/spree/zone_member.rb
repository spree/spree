module Spree
  class ZoneMember < ActiveRecord::Base
    belongs_to :zone
    belongs_to :zoneable, :polymorphic => true

    attr_accessible :zone, :zoneable, :as => :factory

    def name
      return nil if zoneable.nil?
      zoneable.name
    end
  end
end
