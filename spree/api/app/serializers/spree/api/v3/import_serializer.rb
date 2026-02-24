# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ImportSerializer < BaseSerializer
        typelize number: :string, type: [:string, nullable: true], status: :string,
                 owner_type: [:string, nullable: true], owner_id: [:string, nullable: true],
                 user_id: [:string, nullable: true], rows_count: :number

        attributes :number, :type, :rows_count,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :status do |import|
          import.status.to_s
        end

        attribute :owner_type do |import|
          import.owner_type
        end

        attribute :owner_id do |import|
          import.owner&.prefixed_id
        end

        attribute :user_id do |import|
          import.user&.prefixed_id
        end
      end
    end
  end
end
