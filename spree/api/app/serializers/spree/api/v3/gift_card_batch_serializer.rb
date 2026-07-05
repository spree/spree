# frozen_string_literal: true

module Spree
  module Api
    module V3
      class GiftCardBatchSerializer < BaseSerializer
        typelize codes_count: :number, amount: [:string, nullable: true], currency: [:string, nullable: true],
                 prefix: [:string, nullable: true], expires_at: [:string, nullable: true],
                 created_by_id: [:string, nullable: true]

        attributes :codes_count, :currency, :prefix,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :amount do |batch|
          batch.amount&.to_s
        end

        attribute :expires_at do |batch|
          batch.expires_at&.iso8601
        end

        attribute :created_by_id do |batch|
          batch.created_by&.prefixed_id
        end
      end
    end
  end
end
