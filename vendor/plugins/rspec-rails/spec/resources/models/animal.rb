class Animal < ActiveRecord::Base
  belongs_to :person
  validates_uniqueness_of :name
end
