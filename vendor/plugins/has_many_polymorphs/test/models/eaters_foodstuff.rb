
class EatersFoodstuff < ActiveRecord::Base
  belongs_to :foodstuff, :class_name => "Petfood", :foreign_key => "foodstuff_id"
  belongs_to :eater, :polymorphic => true
  
  def before_save
    self.some_attribute = 3
  end
end

