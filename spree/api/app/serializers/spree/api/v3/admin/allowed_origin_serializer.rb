# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class AllowedOriginSerializer < V3::BaseSerializer
          typelize origin: :string

          attributes :origin, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
