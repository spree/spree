module Spree
  module Imports
    module RowProcessors
      class Base
        def initialize(row)
          @row = row
          @import = row.import
          @attributes = row.to_schema_hash
        end

        attr_reader :row, :import, :attributes

        def process!
          raise NotImplementedError, 'Subclasses must implement the process! method'
        end
      end
    end
  end
end
