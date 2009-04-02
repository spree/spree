class ZoneMember < ActiveRecord::Base
  belongs_to :zone
  belongs_to :zoneable, :polymorphic => true
end
