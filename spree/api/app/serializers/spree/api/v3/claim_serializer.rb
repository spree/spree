# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of a claim.
      class ClaimSerializer < BaseSerializer
        typelize number: :string,
                 status: :string,
                 resolution: [:string, nullable: true],
                 order_id: [:string, nullable: true],
                 reason_id: [:string, nullable: true],
                 refund_total: :string,
                 display_refund_total: :string,
                 approved_at: [:string, nullable: true],
                 resolved_at: [:string, nullable: true],
                 denied_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :number, :status, :resolution

        attribute :order_id do |claim|
          claim.order&.prefixed_id
        end

        attribute :reason_id do |claim|
          claim.reason&.prefixed_id
        end

        attribute :refund_total do |claim|
          claim.refund_total.to_s
        end

        attribute :display_refund_total do |claim|
          claim.display_refund_total.to_s
        end

        attribute :approved_at do |claim|
          claim.approved_at&.iso8601
        end

        attribute :resolved_at do |claim|
          claim.resolved_at&.iso8601
        end

        attribute :denied_at do |claim|
          claim.denied_at&.iso8601
        end

        attribute :canceled_at do |claim|
          claim.canceled_at&.iso8601
        end

        one :reason, resource: proc { Spree.api.claim_reason_serializer }, if: proc { expand?('reason') }

        many :claim_line_items,
             resource: proc { Spree.api.claim_line_item_serializer },
             if: proc { expand?('claim_line_items') }
      end
    end
  end
end
