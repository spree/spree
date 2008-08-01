class OptionType < ActiveRecord::Base
  has_many :option_values, :order => :position, :dependent => :destroy
  validates_presence_of [:name, :presentation]
end