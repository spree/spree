module Searchlogic
  module Condition
    class InclusiveDescendantOf < NestedSet
      def to_conditions(value)
        root = (value.is_a?(klass) ? value : klass.find(value)) rescue return
        ["(#{quoted_table_name}.#{quote_column_name(klass.left_column_name)} >= ? AND #{quoted_table_name}.#{quote_column_name(klass.right_column_name)} <= ?)", root.left, root.right]
      end
    end
  end
end