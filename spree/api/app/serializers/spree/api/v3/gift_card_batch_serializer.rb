# frozen_string_literal: true

module Spree
  module Api
    module V3
      class GiftCardBatchSerializer < BaseSerializer
        typelize codes_count: :number, currency: [:string, nullable: true],
                 prefix: [:string, nullable: true], expires_at: [:string, nullable: true],
                 created_by_id: [:string, nullable: true]

        attributes :codes_count, :currency, :prefix,
                   created_at: :iso8601, updated_at: :iso8601

        money_attributes :amount

        attribute :expires_at do |batch|
          batch.expires_at&.iso8601
        end

        prefixed_id_attributes :created_by
      end
    end
  end
end
