# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of a claim.
      class ClaimSerializer < BaseSerializer
        typelize number: :string,
                 status: [:string, enum: Spree::Claim.statuses, enum_type_name: 'ClaimStatus'],
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

        prefixed_id_attributes :order, :reason

        attributes refund_total: :string, display_refund_total: :string
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
