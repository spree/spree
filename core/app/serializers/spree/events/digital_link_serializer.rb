# frozen_string_literal: true

module Spree
  module Events
    class DigitalLinkSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          digital_id: resource.digital_id,
          line_item_id: resource.line_item_id,
          access_counter: resource.access_counter,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
