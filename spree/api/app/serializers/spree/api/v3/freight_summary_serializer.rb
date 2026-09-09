module Spree
  module Api
    module V3
      # A shipment as a freight forwarder reads it: units, the cartons they
      # fill, the pallets those stack onto, cubic meters and gross weight.
      #
      # +complete+ is false when part of the catalog carries no carton data.
      # The figures are still the best available, but they are a minimum
      # rather than a total, and a surface quoting from them should say so.
      #
      # Totals only. What each product contributes is a warehouse's business,
      # so the per-line breakdown lives on the admin twin.
      class FreightSummarySerializer < BaseSerializer
        # A value object, not a record — it has no id of its own.
        _attributes.delete(:id)

        typelize total_units: :number,
                 total_cartons: :number,
                 total_pallets: ['number | null'],
                 total_volume: :string,
                 total_weight: :string,
                 complete: :boolean

        attributes :total_units, :total_cartons, :total_pallets

        attribute :total_volume do |summary|
          decimal_string(summary.total_volume)
        end

        attribute :total_weight do |summary|
          decimal_string(summary.total_weight)
        end

        attribute :complete, &:complete?
      end
    end
  end
end
