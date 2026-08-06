module Spree
  module Api
    module V3
      module Admin
        # Admin-only: tax rates are the internal provider's configuration, never
        # customer-facing. What the customer sees is the label on a tax line.
        class TaxRateSerializer < V3::BaseSerializer
          typelize name: :string,
                   amount: :string,
                   amount_percentage: [:number, nullable: true],
                   included_in_price: :boolean,
                   show_rate_in_label: :boolean,
                   tax_category_id: [:string, nullable: true],
                   store_id: [:string, nullable: true],
                   zone_id: [:string, nullable: true],
                   metadata: ['Record<string, unknown>', nullable: true],
                   deleted_at: [:string, nullable: true]

          attributes :name, :included_in_price, :show_rate_in_label, :metadata,
                     created_at: :iso8601, updated_at: :iso8601, deleted_at: :iso8601

          attribute :amount do |tax_rate|
            tax_rate.amount&.to_s
          end

          # A real number, unlike the money-style `amount` string — this is a
          # percentage for display, not an amount to round-trip exactly.
          attribute :amount_percentage do |tax_rate|
            tax_rate.amount_percentage&.to_f
          end

          attribute :tax_category_id do |tax_rate|
            tax_rate.tax_category&.prefixed_id
          end

          attribute :store_id do |tax_rate|
            tax_rate.store&.prefixed_id
          end

          attribute :zone_id do |tax_rate|
            tax_rate.zone&.prefixed_id
          end
        end
      end
    end
  end
end
