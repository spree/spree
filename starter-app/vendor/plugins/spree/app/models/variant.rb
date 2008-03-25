class Variant < ActiveRecord::Base
  belongs_to :product
  has_and_belongs_to_many :option_values
  validates_presence_of :product
end
