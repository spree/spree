class StateEvent < ActiveRecord::Base
  belongs_to :user
  belongs_to :order
  
  def <=>(other)
    created_at <=> other.created_at
  end
end
