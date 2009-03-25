module Searchlogic
  module Condition
    class Nil < Base
      self.value_type = :boolean
      
      class << self
        def condition_names_for_column
          super + ["is_nil", "is_null", "null"]
        end
      end
      
      def to_conditions(value)
        if value == true
          "#{column_sql} IS NULL"
        elsif value == false
          "#{column_sql} IS NOT NULL"
        end
      end
    end
  end
end