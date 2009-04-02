class Country < ActiveRecord::Base
  has_many :states
  named_scope :order_by_name, :order => :name  

  def <=>(other)
    name <=> other.name
  end
end