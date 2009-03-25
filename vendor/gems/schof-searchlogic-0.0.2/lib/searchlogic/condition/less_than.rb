module Searchlogic
  module Condition
    class LessThan < Base
      class << self
        def condition_names_for_column
          super + ["lt", "before"]
        end
      end
      
      def to_conditions(value)
        ["#{column_sql} < ?", value]
      end
    end
  end
end