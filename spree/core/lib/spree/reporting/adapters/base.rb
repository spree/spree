module Spree
  module Reporting
    module Adapters
      # Storage adapter contract. Adapters receive a normalized
      # Spree::Reporting::Query and return a Spree::Reporting::Result with raw
      # numeric values — the query never changes shape across adapters, which
      # is what lets storage move from live OLTP to fact tables (or an
      # external OLAP store) without touching consumers.
      #
      # Post-aggregation metric semantics (value casting, derived ratios, the
      # nil-baseline growth convention) live here so every adapter reports
      # identical numbers — the drift between hand-rolled growth
      # implementations is what this layer replaces.
      class Base
        def execute(query)
          raise NotImplementedError, "#{self.class.name} must implement #execute"
        end

        protected

        attr_reader :query

        def cast_value(metric, raw)
          case metric.format
          when :money, :decimal then raw.to_f.round(2)
          else raw.to_i
          end
        end

        def zero_for(metric)
          metric.format == :integer ? 0 : 0.0
        end

        # Computes requested ratio metrics from their aggregated components.
        def apply_derived(metrics)
          query.metrics.select(&:derived?).each do |metric|
            numerator, denominator = metric.ratio.map { |name| metrics[name] || 0 }
            metrics[metric.name] = denominator.to_f.zero? ? 0.0 : (numerator / denominator.to_f).round(2)
          end
        end

        def metric_payload(value, previous)
          payload = { value: value }
          if query.compare?
            payload[:previous] = previous
            payload[:growth] = growth_rate(value, previous)
          end
          payload
        end

        # Percentage change vs the previous period. nil when there is no
        # previous-period baseline (previous == 0 with current activity) so
        # clients can render "new" instead of a misleading 0%.
        def growth_rate(current, previous)
          return nil if previous.nil?
          if previous.zero?
            return 0.0 if current.zero?

            return nil
          end

          (((current - previous) / previous.to_f) * 100).round(1)
        end
      end
    end
  end
end
