# frozen_string_literal: true

module Spree
  module Events
    class AssetSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          type: resource.type,
          viewable_type: resource.viewable_type,
          viewable_id: association_prefix_id(:viewable),
          position: resource.position,
          alt: resource.alt,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
