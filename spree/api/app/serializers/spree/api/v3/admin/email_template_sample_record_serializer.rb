module Spree
  module Api
    module V3
      module Admin
        class EmailTemplateSampleRecordSerializer < V3::BaseSerializer
          typelize label: :string, created_at: :string

          attributes :label, created_at: :iso8601
        end
      end
    end
  end
end
