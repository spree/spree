class Variation < ActiveRecord::Base
  belongs_to :product
  has_and_belongs_to_many :option_values
  validates_presence_of :product
  #has_one :sku
  #belongs_to :variable, :polymorphic => true
  #validates_presence_of :name  
end
