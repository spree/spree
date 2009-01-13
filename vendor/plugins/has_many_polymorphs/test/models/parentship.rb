class Parentship < ActiveRecord::Base     
  belongs_to :parent, :class_name => "Person", :foreign_key => "parent_id"
  belongs_to :kid, :polymorphic => true, :foreign_type => "child_type"
end
