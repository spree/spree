# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ExportSerializer < BaseSerializer
        typelize number: :string, type: [:string, nullable: true], format: [:string, nullable: true],
                 user_id: [:string, nullable: true]

        attributes :number, :format,
                   created_at: :iso8601, updated_at: :iso8601

        # Wire shorthand (`"products"`), not the Ruby class name — clients
        # shouldn't have to know or parse `Spree::Exports::Products`. Read from
        # the STI column rather than the instance's class so a record loaded as
        # the base Spree::Export still reports its real type.
        attribute :type do |export|
          Spree::Export.api_type_for(export.type)
        end

        attribute :user_id do |export|
          export.user&.prefixed_id
        end
      end
    end
  end
end
