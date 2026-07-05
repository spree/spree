module Spree
  module Api
    module V3
      module Admin
        class DigitalLinkSerializer < V3::DigitalLinkSerializer
          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
