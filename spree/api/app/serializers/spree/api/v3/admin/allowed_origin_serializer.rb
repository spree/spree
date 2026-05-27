# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class AllowedOriginSerializer < V3::BaseSerializer
          typelize origin: :string,
                   store_id: :string

          attributes :origin, created_at: :iso8601, updated_at: :iso8601

          # All rows share `current_store` because `Spree::AllowedOrigin`
          # is a `SingleStoreResource` — avoid the per-row association load.
          attribute :store_id do |_allowed_origin|
            current_store&.prefixed_id
          end
        end
      end
    end
  end
end
