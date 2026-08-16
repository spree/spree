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
                   vendor_id: :string,
                   vendor_name: 'string | null',
                   line_item_id: 'string | null',
                   fulfillment_id: 'string | null',
                   commission_rate_id: 'string | null',
                   kind: :string,
                   rate: :string,
                   amount: :string,
                   tax_amount: :string,
                   total: :string,
                   currency: :string,
                   display_amount: :string,
                   display_tax_amount: :string,
                   display_total: :string

          attributes :kind, :currency, created_at: :iso8601, updated_at: :iso8601

          # Strings, so the figures a seller is invoiced round-trip exactly.
          %i[rate amount tax_amount total].each do |decimal|
            attribute(decimal) { |line| line.public_send(decimal)&.to_s }
          end

          %i[display_amount display_tax_amount display_total].each do |formatted|
            attribute(formatted) { |line| line.public_send(formatted).to_s }
          end

          %i[order vendor line_item fulfillment commission_rate].each do |association|
            attribute(:"#{association}_id") { |line| line.public_send(association)&.prefixed_id }
          end

          # The seller's name, so a commission table reads without expanding.
          attribute :vendor_name do |line|
            line.vendor&.name
          end
        end
      end
    end
  end
end
