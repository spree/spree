module Searchlogic
  module Condition
    class NotEqual < Base
      self.handle_array_value = true
      self.ignore_meaningless_value = false
      
      class << self
        def condition_names_for_column
          super + ["does_not_equal", "not_equal", "is_not", "not", "ne"]
        end
      end
      
      def to_conditions(value)
        # Delegate to equals and then change
        condition = Equals.new(klass, options)
        condition.value = value
        conditions_array = condition.sanitize
        return conditions_array if conditions_array.blank?
        conditions_array.first.gsub!(/ IS /, " IS NOT ")
        conditions_array.first.gsub!(/ BETWEEN /, " NOT BETWEEN ")
        conditions_array.first.gsub!(/ IN /, " NOT IN ")
        conditions_array.first.gsub!(/=/, "!=")
        conditions_array
      end
    end
  end
end