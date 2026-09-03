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
                   commission_rate_name: 'string | null',
                   line_item_id: 'string | null',
                   fulfillment_id: 'string | null',
                   commission_rate_id: 'string | null',
                   kind: :string,
                   rate: :string,
                   tax_rate: :string,
                   taxability_reason: 'string | null',
                   country_code: 'string | null',
                   state_code: 'string | null',
                   amount: :string,
                   tax_amount: :string,
                   total: :string,
                   currency: :string,
                   display_amount: :string,
                   display_tax_amount: :string,
                   display_total: :string

          # The treatment, in Spree::TaxLine's vocabulary — a seller's invoice
          # has to explain why its fee was taxed the way it was, and the
          # jurisdiction is the seller's own rather than the shopper's.
          attributes :kind, :currency, :taxability_reason, :country_code, :state_code,
                     created_at: :iso8601, updated_at: :iso8601

          # Strings, so the figures a seller is invoiced round-trip exactly.
          %i[rate tax_rate amount tax_amount total].each do |decimal|
            attribute(decimal) { |line| line.public_send(decimal)&.to_s }
          end

          %i[display_amount display_tax_amount display_total].each do |formatted|
            attribute(formatted) { |line| line.public_send(formatted).to_s }
          end

          %i[order seller line_item fulfillment commission_rate].each do |association|
            attribute(:"#{association}_id") { |line| line.public_send(association)&.prefixed_id }
          end

          # The seller's name, so a commission table reads without expanding.
          attribute :seller_name do |line|
            line.seller&.name
          end

          # The rate that applied, so an order's commission reads without expanding.
          attribute :commission_rate_name do |line|
            line.commission_rate&.name
          end
        end
      end
    end
  end
end
