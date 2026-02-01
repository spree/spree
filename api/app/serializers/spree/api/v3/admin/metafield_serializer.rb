module Spree
  module Api
    module V3
      module Admin
        # Admin API Metafield Serializer
        # Full metafield data including admin-only fields
        class MetafieldSerializer < V3::MetafieldSerializer
          typelize display_on: :string

          attributes :display_on
        end
      end
    end
  end
end
