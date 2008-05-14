class TaxRate < ActiveRecord::Base
  belongs_to :state
  validates_uniqueness_of :state_id
  validates_numericality_of :rate
  validates_presence_of :rate
end
