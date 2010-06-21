class Prototype < ActiveRecord::Base
  has_and_belongs_to_many :properties
  has_and_belongs_to_many :option_types
  validates :name, :presence => true
end