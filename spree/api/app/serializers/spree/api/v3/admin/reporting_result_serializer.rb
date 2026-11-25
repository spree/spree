module Spree
  module Api
    module V3
      module Admin
        # Writes a Spree::Reporting::Result for the wire: money as decimal
        # strings in the result's currency, ratios and growth as plain decimal
        # strings, counts as integers, money display strings, ISO ranges, and
        # dimension hydration (raw group keys become { id, label, meta }
        # display payloads — see Spree::Reporting::Hydration).
        class ReportingResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize totals: ['Record<string, ReportingMetricValue>',
                            comment: 'Each metric over the whole period, by metric name. Filters on a metric narrow the rows ' \
                                     'only, never these.'],
                   rows: [:ReportingRow, multi: true]

          one :meta, resource: ReportingResultMetaSerializer

          attribute :totals do |result|
            ReportingMetricValueSerializer.keyed(result.totals, currency: currency)
          end

          attribute :rows do |result|
            ReportingRowSerializer.new(result.rows, params: { hydration: hydration, currency: currency }).to_h
          end

          private

          def currency
            @currency ||= ::Money::Currency.find(object.meta[:currency])
          end

          def hydration
            @hydration ||= Spree::Reporting::Hydration.new(object, store: params[:store], params: params)
          end
        end
      end
    end
  end
end
