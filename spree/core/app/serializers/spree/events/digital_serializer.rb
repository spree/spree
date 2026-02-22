# frozen_string_literal: true

module Spree
  module Events
    class DigitalSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          variant_id: public_id(resource.variant),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
