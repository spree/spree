# frozen_string_literal: true

module Spree
  module Events
    class DigitalSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          variant_id: association_prefix_id(:variant),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
