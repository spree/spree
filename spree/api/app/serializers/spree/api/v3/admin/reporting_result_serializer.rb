module Spree
  module Api
    module V3
      module Admin
        # Decorates a Spree::Reporting::Result for the wire: money display
        # strings, ISO ranges, and dimension hydration — raw group keys become
        # { id, label, meta } display payloads via each dimension's registered
        # `hydrate` lambda, batched once per dimension across all rows.
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
            output[:display] = money(payload[:value]) if Spree.reporting.metrics[name]&.money?
            output
          end

          def money(amount)
            Spree::Money.new(amount, currency: result.meta[:currency]).to_s
          end

          def dimension_value(name, raw)
            return raw unless dimension_defs[name].hydrate

            hydrated_dimensions[name][raw] || { id: nil, label: raw.to_s, meta: {} }
          end

          def dimension_defs
            @dimension_defs ||= Hash.new { |cache, name| cache[name] = Spree.reporting.dimension!(name) }
          end

          # One batched `hydrate` call per hydrated dimension across all rows.
          def hydrated_dimensions
            @hydrated_dimensions ||= begin
              keys = Hash.new { |h, k| h[k] = [] }
              result.rows.each do |row|
                row[:dimensions].each do |name, raw|
                  keys[name] << raw if dimension_defs[name].hydrate
                end
              end

              keys.to_h do |name, raws|
                [name, dimension_defs[name].hydrate.call(store, raws.uniq, params)]
              end
            end
          end
        end
      end
    end
  end
end
