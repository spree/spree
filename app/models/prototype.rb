class Prototype < ActiveRecord::Base
  has_and_belongs_to_many :properties
  validates_presence_of :name
end