class Spree::Prototype < ActiveRecord::Base
  has_and_belongs_to_many :properties, :class_name => 'Spree::Property'
  has_and_belongs_to_many :option_types, :class_name => 'Spree::OptionType'
  validates :name, :presence => true
end
