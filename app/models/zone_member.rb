class ZoneMember < ActiveRecord::Base
  belongs_to :parent, :class_name => "Zone", :foreign_key => "parent_id"
  belongs_to :member, :polymorphic => true
end
