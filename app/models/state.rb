class State < ActiveRecord::Base
  belongs_to :country
  named_scope :order_by_name, :order => :name
  
  validates_presence_of [:country, :name]
  
  def <=>(other)
    name <=> other.name
  end
   
end