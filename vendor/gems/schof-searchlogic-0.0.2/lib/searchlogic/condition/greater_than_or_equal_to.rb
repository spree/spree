module Searchlogic
  module Condition
    class GreaterThanOrEqualTo < Base
      class << self
        def condition_names_for_column
          super + ["gte", "at_least", "least"]
        end
      end
      
      def to_conditions(value)
        ["#{column_sql} >= ?", value]
      end
    end
  end
end