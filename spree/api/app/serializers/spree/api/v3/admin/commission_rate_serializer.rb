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
          typelize name: :string,
                   code: 'string | null',
                   enabled: :boolean,
                   position: :number,
                   global: :boolean,
                   kind: [:string, enum: Spree::CommissionRate::KINDS],
                   amounts: 'Record<string, string>',
                   bounds: 'Record<string, { min_amount: string | null; max_amount: string | null }>',
                   tax_inclusive: :boolean,
                   include_shipping: :boolean,
                   metadata: 'Record<string, unknown> | null',
                   deleted_at: 'string | null'

          attributes :name, :code, :enabled, :position, :kind,
                     :tax_inclusive, :include_shipping, :metadata,
                     deleted_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

          # +value+ is the percentage a percentage rate charges; a flat fee's
          # money lives in +amounts+, per currency.
          rate_attributes :value, :commission_tax_rate
          typelize value: [:string, nullable: false]

          # What a flat fee charges, per currency. Empty on a percentage rate,
          # which needs no amount of its own.
          attribute :amounts do |rate|
            rate.amounts.to_h { |currency, amount| [currency, Spree::Money::Rounding.format(amount, currency)] }
          end

          # The floor and cap a percentage charges within, per currency. Each
          # holds only in its own currency, so a rate may bound some and leave
          # others unbounded.
          attribute :bounds do |rate|
            rate.bounds.to_h do |currency, bound|
              [currency, bound.transform_values { |amount| Spree::Money::Rounding.format(amount, currency) }]
            end
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
