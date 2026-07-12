module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::ImportRow}. Adds the raw CSV row
        # (`data`) so the failure report can show the offending values.
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
