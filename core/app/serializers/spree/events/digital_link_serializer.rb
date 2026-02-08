# frozen_string_literal: true

module Spree
  module Events
    class DigitalLinkSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          digital_id: association_prefix_id(:digital),
          line_item_id: association_prefix_id(:line_item),
          access_counter: resource.access_counter,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
