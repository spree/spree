module Spree
  module Api
    module V3
      module Admin
        class CategoryPublicationSerializer < V3::CategoryPublicationSerializer
          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
