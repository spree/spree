class Country < ActiveRecord::Base
  has_many :states
  has_and_belongs_to_many :zones
end