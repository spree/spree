module Spree
  module Imports
    module RowsPreprocessors
      class Base
        def initialize(import)
          @import = import
        end

        def preprocess_rows!
          # no-op by default
        end

        private

        attr_reader :import
      end
    end
  end
end
