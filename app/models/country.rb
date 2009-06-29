class Country < ActiveRecord::Base
  has_many :states
  named_scope :order_by_name, :order => :name  
  validates_presence_of :name  
  validates_presence_of :iso_name
  
  def <=>(other)
    name <=> other.name
  end
end