# frozen_string_literal: true

module Spree
  module Events
    class DigitalLinkSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          digital_id: public_id(resource.digital),
          line_item_id: public_id(resource.line_item),
          access_counter: resource.access_counter,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
