class OrderOperation < ActiveRecord::Base  
  belongs_to :user
  belongs_to :order
  
  enumerable_constant :operation_type, {:constants => ORDER_OPERATIONS, :no_validation => true}

end