# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ImportSerializer < BaseSerializer
        typelize number: :string, type: [:string, nullable: true], status: :string,
                 owner_type: [:string, nullable: true], owner_id: [:string, nullable: true],
                 store_id: [:string, nullable: true], seller_id: [:string, nullable: true],
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

        # Which marketplace this import belongs to, and — when a seller ran it —
        # whose it is. A null `seller_id` means the operator's own.
        attribute :store_id do |import|
          import.store&.prefixed_id
        end

        attribute :seller_id do |import|
          import.seller&.prefixed_id
        end

        # @deprecated Read `store_id` / `seller_id` — removed in 6.1. Emitted
        #   from the pair above rather than the dropped columns, so a client
        #   still reading them sees the same answer.
        attribute :owner_type do |import|
          Spree::Base.polymorphic_api_type(import.seller_id.present? ? 'Spree::Seller' : 'Spree::Store')
        end

        attribute :owner_id do |import|
          (import.seller || import.store)&.prefixed_id
        end

        attribute :user_id do |import|
          import.user&.prefixed_id
        end
      end
    end
  end
end
