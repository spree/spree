# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ImportSerializer < BaseSerializer
        typelize number: :string, type: [:string, nullable: true], status: :string,
                 owner_type: [:string, nullable: true], owner_id: [:string, nullable: true],
                 user_id: [:string, nullable: true], rows_count: :number

        attributes :number, :rows_count,
                   created_at: :iso8601, updated_at: :iso8601

        # Wire shorthand (`"products"`), not the Ruby class name — clients
        # shouldn't have to know or parse `Spree::Imports::Products`. Read from
        # the STI column rather than the instance's class so a record loaded as
        # the base Spree::Import still reports its real type.
        attribute :type do |import|
          Spree::Import.api_type_for(import.type)
        end

        attribute :status do |import|
          import.status.to_s
        end

        # `"store"` / `"seller"`, not the polymorphic class name.
        attribute :owner_type do |import|
          Spree::Base.polymorphic_api_type(import.owner_type)
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
