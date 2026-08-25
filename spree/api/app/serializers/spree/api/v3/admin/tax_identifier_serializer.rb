module Spree
  module Api
    module V3
      module Admin
        class TaxIdentifierSerializer < V3::TaxIdentifierSerializer
          typelize validation_status: [:string, nullable: true],
                   validated_at: [:string, nullable: true],
                   validation_evidence: ['Record<string, unknown>', nullable: true],
                   source: [:string, nullable: true],
                   validatable: :boolean,
                   customer_id: [:string, nullable: true],
                   cart_id: [:string, nullable: true],
                   order_id: [:string, nullable: true]

          attributes :validation_status, :validation_evidence, :source,
                     validated_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          # Whether this installation can check a number of this kind at all —
          # what tells a nil verdict "not checked yet" apart from "nothing here
          # knows how to ask".
          attribute :validatable do |tax_identifier|
            tax_identifier.validatable?
          end

          # The owner, reported under the name of what it is, so a client can
          # tell a customer's durable registration from a cart override or an
          # order's snapshot without reading a type string.
          attribute :customer_id do |tax_identifier|
            tax_identifier.owner&.prefixed_id if tax_identifier.owner.is_a?(Spree.customer_class)
          end

          attribute :cart_id do |tax_identifier|
            tax_identifier.owner&.prefixed_id if tax_identifier.owner.is_a?(Spree::Cart)
          end

          attribute :order_id do |tax_identifier|
            tax_identifier.owner&.prefixed_id if tax_identifier.owner.is_a?(Spree::Order)
          end
        end
      end
    end
  end
end
