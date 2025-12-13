# frozen_string_literal: true

module Spree
  module Events
    class AssetSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          type: resource.type,
          viewable_type: resource.viewable_type,
          viewable_id: resource.viewable_id,
          position: resource.position,
          alt: resource.alt,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
