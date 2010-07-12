class OptionType < ActiveRecord::Base
  has_many :option_values, :order => :position, :dependent => :destroy
  has_many :product_option_types, :dependent => :destroy
  has_and_belongs_to_many :prototypes
  validates :name, :presentation, :presence => true
end
