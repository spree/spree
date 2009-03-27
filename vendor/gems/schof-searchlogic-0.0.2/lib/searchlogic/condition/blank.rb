module Searchlogic
  module Condition
    class Blank < Base
      self.value_type = :boolean
      
      class << self
        def condition_names_for_column
          super + ["is_blank"]
        end
      end
      
      def to_conditions(value)
        if value == true
          "(#{column_sql} IS NULL or #{column_sql} = '' or #{column_sql} = false)"
        elsif value == false
          "(#{column_sql} IS NOT NULL and #{column_sql} != '' and #{column_sql} != false)"
        end
      end
    end
  end
end