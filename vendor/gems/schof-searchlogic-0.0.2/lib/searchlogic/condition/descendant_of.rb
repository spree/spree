module Searchlogic
  module Condition
    class DescendantOf < NestedSet
      def to_conditions(value)
        condition = InclusiveDescendantOf.new(klass, options)
        condition.value = value
        scope_condition(merge_conditions(["#{quoted_table_name}.#{quote_column_name(klass.primary_key)} != ?", (value.is_a?(klass) ? value.send(klass.primary_key) : value)], condition.sanitize))
      end
    end
  end
end