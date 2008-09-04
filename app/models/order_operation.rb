class OrderOperation < ActiveRecord::Base  
  belongs_to :user
  belongs_to :order
  
  enumerable_constant :operation_type, {:constants => [:authorize, :capture, :cancel, :return, :ship, :comp, :delete], :no_validation => true}

end