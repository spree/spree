module Searchlogic
  module Condition
    class ChildOf < NestedSet
      def to_conditions(value)
        parent_association = klass.reflect_on_association(:parent)
        foreign_key_name = (parent_association && parent_association.options[:foreign_key]) || "parent_id"
        ["#{quoted_table_name}.#{quote_column_name(foreign_key_name)} = ?", (value.is_a?(klass) ? value.send(klass.primary_key) : value)]
      end
    end
  end
end