# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Store API Promotion Serializer
      # Minimal public-facing promotion info. Full details in Admin serializer.
      class PromotionSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true],
                 code: [:string, nullable: true]

        attributes :name, :description, :code
      end
    end
  end
end
