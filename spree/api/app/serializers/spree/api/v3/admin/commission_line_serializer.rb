module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CommissionLine — what one sale actually earned the
        # marketplace, frozen at placement.
        #
        # Read-only everywhere: a commission line records something that
        # already happened, so it is never written through the API.
        #
        # `amount` and `tax_amount` stay separate rather than being folded into
        # `total`, because they are two different supplies: the fee, and the
        # VAT the platform charges the seller on that fee. A seller's invoice
        # has to show both.
        class CommissionLineSerializer < V3::BaseSerializer
          typelize order_id: :string,
                   seller_id: :string,
                   seller_name: 'string | null',
                   line_item_id: 'string | null',
                   fulfillment_id: 'string | null',
                   commission_rate_id: 'string | null',
                   kind: [:string, enum: Spree::CommissionRate::KINDS],
                   taxability_reason: 'string | null',
                   country_code: 'string | null',
                   state_code: 'string | null',
                   currency: :string

          # The treatment, in Spree::TaxLine's vocabulary — a seller's invoice
          # has to explain why its fee was taxed the way it was, and the
          # jurisdiction is the seller's own rather than the shopper's.
          attributes :kind, :currency, :taxability_reason, :country_code, :state_code,
                     created_at: :iso8601, updated_at: :iso8601

          rate_attributes :rate, :tax_rate
          money_attributes :amount, :tax_amount, :total
          typelize rate: [:string, nullable: false], tax_rate: [:string, nullable: false],
                   amount: [:string, nullable: false], tax_amount: [:string, nullable: false],
                   total: [:string, nullable: false]

          %i[order seller line_item fulfillment commission_rate].each do |association|
            attribute(:"#{association}_id") { |line| line.public_send(association)&.prefixed_id }
          end

          # The seller's name, so a commission table reads without expanding.
          attribute :seller_name do |line|
            line.seller&.name
          end

          one :commission_rate,
              resource: proc { Spree.api.admin_commission_rate_serializer },
              if: proc { expand?('commission_rate') }
        end
      end
    end
  end
end
