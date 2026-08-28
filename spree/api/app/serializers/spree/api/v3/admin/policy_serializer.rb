module Spree
  module Api
    module V3
      module Admin
        class PolicySerializer < V3::PolicySerializer
          attributes created_at: :iso8601
        end
      end
    end
  end
end
