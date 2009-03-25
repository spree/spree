module Searchlogic
  module Condition
    class NestedSet < Base # :nodoc:
      self.join_arrays_with_or = true
      
      class << self
        def condition_names_for_column
          []
        end
        
        def condition_names_for_model
          [condition_type_name]
        end
      end
    end
  end
end