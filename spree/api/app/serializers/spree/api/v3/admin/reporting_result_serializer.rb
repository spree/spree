module Spree
  module Api
    module V3
      module Admin
        # Decorates a Spree::Reporting::Result for the wire: money display
        # strings, ISO ranges, and dimension hydration (raw group keys become
        # { id, label, meta } display payloads — see Spree::Reporting::Hydration).
        class ReportingResultSerializer
          attr_reader :result, :store, :params

          def initialize(result, store:, params: {})
            @result = result
            @store = store
            @params = params
          end

          def to_h
            {
              meta: result.meta.merge(
                time_range: iso_range(result.meta[:time_range]),
                previous_time_range: iso_range(result.meta[:previous_time_range])
              ),
              totals: result.totals.to_h { |name, payload| [name, metric_payload(name, payload)] },
              rows: result.rows.map do |row|
                {
                  dimensions: row[:dimensions].to_h { |name, raw| [name, dimension_value(name, raw)] },
                  metrics: row[:metrics].to_h { |name, payload| [name, metric_payload(name, payload)] }
                }
              end
            }
          end

          private

          def iso_range(range)
            return unless range

            { since: range.first.iso8601, until: range.last.iso8601 }
          end

          def metric_payload(name, payload)
            output = payload.dup
            output[:display] = money(payload[:value]) if money_metrics.include?(name)
            output
          end

          # Resolved once per response rather than per cell — a 1000-row report
          # with five metrics would otherwise build 5000 Money objects.
          def money_metrics
            @money_metrics ||= result.meta[:metrics].select { |name| Spree.reporting.metrics[name]&.money? }.to_set
          end

          def currency
            @currency ||= ::Money::Currency.find(result.meta[:currency])
          end

          def money(amount)
            Spree::Money.new(amount, currency: currency).to_s
          end

          def dimension_value(name, raw)
            hydration.value(name, raw)
          end

          def hydration
            @hydration ||= Spree::Reporting::Hydration.new(result, store: store, params: params)
          end
        end
      end
    end
  end
end
