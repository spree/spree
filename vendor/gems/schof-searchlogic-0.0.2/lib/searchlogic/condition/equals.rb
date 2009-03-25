module Searchlogic
  module Condition
    class Equals < Base
      self.handle_array_value = true
      self.ignore_meaningless_value = false
      
      class << self
        def condition_names_for_column
          super + ["", "is"]
        end
      end
      
      def to_conditions(value)
        return value if value.is_a?(Array) && value.empty?
        
        # Let ActiveRecord handle this
        args = []
        case value
        when Range
          args = [value.first, value.last]
        else
          args << value
        end
        
        begin
          return [klass.send(:attribute_condition, column_sql, value), *args]
        rescue ArgumentError
          return ["#{column_sql} #{klass.send(:attribute_condition, value)}", *args] # for older versions of AR
        end
      end
    end
  end
end