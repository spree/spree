module Spree
  module Api
    module V3
      module Seller
        # One row of a seller's import. Adds the raw CSV row (`data`) so the
        # failure report can show the values that were rejected.
        class ImportRowSerializer < V3::ImportRowSerializer
          typelize data: 'Record<string, string | null>'

          attribute :data do |row|
            row.data_json
          end
        end
      end
    end
  end
end
