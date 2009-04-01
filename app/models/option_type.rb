class OptionType < ActiveRecord::Base
  has_many :option_values, :order => :position, :dependent => :destroy, :attributes => true
  has_and_belongs_to_many :prototypes
  validates_presence_of [:name, :presentation]
end