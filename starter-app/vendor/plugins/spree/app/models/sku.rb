class Sku < ActiveRecord::Base
  belongs_to :stockable, :polymorphic => true
  
  def to_s
    number
  end
end
