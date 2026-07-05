module Spree
  module Imports
    module RowProcessors
      class Base
        def initialize(row, mappings: nil, schema_fields: nil)
          @row = row
          @import = row.import
          @attributes = if mappings && schema_fields
                          build_schema_hash(row, mappings, schema_fields)
                        else
                          row.to_schema_hash
                        end
        end

        attr_reader :row, :import, :attributes

        def process!
          raise NotImplementedError, 'Subclasses must implement the process! method'
        end

        private

        def build_schema_hash(row, mappings, schema_fields)
          attributes = {}
          schema_fields.each do |field|
            mapping = mappings.find { |m| m.schema_field == field[:name] }
            next unless mapping&.mapped?

            attributes[field[:name]] = row.data_json[mapping.file_column]
          end
          attributes
        end
      end
    end
  end
end
