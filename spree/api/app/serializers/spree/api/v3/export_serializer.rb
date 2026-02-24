# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ExportSerializer < BaseSerializer
        typelize number: :string, type: [:string, nullable: true], format: [:string, nullable: true],
                 user_id: [:string, nullable: true]

        attributes :number, :type, :format,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :user_id do |export|
          export.user&.prefixed_id
        end
      end
    end
  end
end
