# frozen_string_literal: true

module Spree
  module Api
    module V3
      class DigitalSerializer < BaseSerializer
        typelize variant_id: [:string, nullable: true]

        attributes created_at: :iso8601, updated_at: :iso8601

        attribute :variant_id do |digital|
          digital.variant&.prefixed_id
        end
      end
    end
  end
end
