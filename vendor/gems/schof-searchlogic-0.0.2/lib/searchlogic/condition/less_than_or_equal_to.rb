module Searchlogic
  module Condition
    class LessThanOrEqualTo < Base
      class << self
        def condition_names_for_column
          super + ["lte", "at_most", "most"]
        end
      end
      
      def to_conditions(value)
        ["#{column_sql} <= ?", value]
      end
    end
  end
end