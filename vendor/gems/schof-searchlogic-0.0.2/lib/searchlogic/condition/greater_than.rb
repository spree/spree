module Searchlogic
  module Condition
    class GreaterThan < Base
      class << self
        def condition_names_for_column
          super + ["gt", "after"]
        end
      end
      
      def to_conditions(value)
        ["#{column_sql} > ?", value]
      end
    end
  end
end