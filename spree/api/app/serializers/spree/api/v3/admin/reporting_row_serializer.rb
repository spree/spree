module Spree
  module Api
    module V3
      module Admin
        # One group of a reporting result. `params` carry the result's
        # hydration and currency, resolved once per response by
        # ReportingResultSerializer.
        class ReportingRowSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize dimensions: ['Record<string, string | ReportingDimensionValue | null>',
                                comment: 'By dimension name: the raw value for plain dimensions (time buckets, country codes), a ' \
                                         'display payload for lookup-backed and enumerated ones.'],
                   metrics: ['Record<string, ReportingMetricValue>', comment: 'By metric name.']

          attribute :dimensions do |row|
            row[:dimensions].to_h { |name, raw| [name, dimension_value(name, raw)] }
          end

          attribute :metrics do |row|
            ReportingMetricValueSerializer.keyed(row[:metrics], currency: params[:currency])
          end

          private

          def dimension_value(name, raw)
            value = params[:hydration].value(name, raw)
            value.is_a?(Hash) ? ReportingDimensionValueSerializer.new(value).to_h : value
          end
        end
      end
    end
  end
end
