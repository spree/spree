class SingleStiParentRelationship < ActiveRecord::Base
  belongs_to :single_sti_parent
  belongs_to :the_bone, :polymorphic => true
end
