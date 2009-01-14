
class Aquatic::PupilsWhale < ActiveRecord::Base
  set_table_name "little_whale_pupils"
  belongs_to :whale, :class_name => "Aquatic::Whale", :foreign_key => "whale_id"
  belongs_to :aquatic_pupil, :polymorphic => true
end

