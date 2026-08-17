module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CommissionRate — what the marketplace charges, as
        # configuration.
        #
        # Admin-only: a rate is a term of business between the operator and its
        # sellers, so it has no Store API counterpart. Sellers read what they
        # were actually charged (Spree::CommissionLine) on their own branch,
        # never the rules that produced it.
        class CommissionRateSerializer < V3::BaseSerializer
          # Decimals serialize as strings, like every other money-ish field on
          # the admin API: a rate has to round-trip exactly, and a float does
          # not promise that.
          typelize name: :string,
                   code: 'string | null',
                   enabled: :boolean,
                   position: :number,
                   global: :boolean,
                   kind: :string,
                   value: :string,
                   currency: 'string | null',
                   tax_inclusive: :boolean,
                   include_shipping: :boolean,
                   min_amount: 'string | null',
                   max_amount: 'string | null',
                   commission_tax_rate: 'string | null',
                   metadata: 'Record<string, unknown> | null',
                   deleted_at: 'string | null'

          attributes :name, :code, :enabled, :position, :kind, :currency,
                     :tax_inclusive, :include_shipping, :metadata,
                     deleted_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          %i[value min_amount max_amount commission_tax_rate].each do |decimal|
            attribute(decimal) { |rate| rate.public_send(decimal)&.to_s }
          end

          # A rate that names nothing matches every sale, so everything below
          # it in the list is unreachable. The dashboard needs to say so.
          attribute :global, &:global?

          # Always embedded rather than expand-gated: a rate without its
          # targeting cannot be read (a rate with no rules means something
          # entirely different from one whose rules were not loaded), and
          # they are a handful of rows.
          many :commission_rules,
               key: :rules,
               resource: proc { Spree.api.admin_commission_rule_serializer }
        end
      end
    end
  end
end
