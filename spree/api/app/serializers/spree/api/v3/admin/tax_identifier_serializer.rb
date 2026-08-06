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

          attribute :customer_id do |tax_identifier|
            tax_identifier.customer&.prefixed_id
          end

          attribute :cart_id do |tax_identifier|
            tax_identifier.cart&.prefixed_id
          end

          attribute :order_id do |tax_identifier|
            tax_identifier.order&.prefixed_id
          end
        end
      end
    end
  end
end
