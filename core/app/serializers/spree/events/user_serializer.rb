# frozen_string_literal: true

module Spree
  module Events
    class UserSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          email: resource.email,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
