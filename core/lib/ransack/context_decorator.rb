require 'ransack'

module Ransack
  module Adapters
    module ActiveRecord
      module ContextDecorator
        def type_for(attr)
          return nil unless attr && attr.valid?
          name         = attr.arel_attribute.name.to_s
          # Patched
          # Original implementation
          # table        = attr.arel_attribute.relation.table_name
          table        = attr.arel_attribute.relation.name
          schema_cache = self.klass.connection.schema_cache
          unless schema_cache.send(:data_source_exists?, table)
            raise "No table named #{table} exists."
          end
          attr.klass.columns.find { |column| column.name == name }.type
        end
      end
    end
  end
end

Ransack::Adapters::ActiveRecord::Context.prepend(Ransack::Adapters::ActiveRecord::ContextDecorator)
