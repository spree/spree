module Searchlogic
  module Condition
    class SiblingOf < NestedSet
      def to_conditions(value)
        parent_association = klass.reflect_on_association(:parent)
        foreign_key_name = (parent_association && parent_association.options[:foreign_key]) || "parent_id"
        parent_id = (value.is_a?(klass) ? value : klass.find(value)).send(foreign_key_name)
        condition = ChildOf.new(klass, options)
        condition.value = parent_id
        merge_conditions(["#{quoted_table_name}.#{quote_column_name(klass.primary_key)} != ?", (value.is_a?(klass) ? value.send(klass.primary_key) : value)], condition.sanitize)
      end
    end
  end
end