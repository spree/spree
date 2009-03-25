module Searchlogic
  module Condition
    class Like < Base
      class << self
        def condition_names_for_column
          super + ["contains", "has"]
        end
      end
      
      def to_conditions(value)
        ["#{column_sql} #{like_condition_name} ?", "%#{value}%"]
      end
    end
  end
end