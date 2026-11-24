module Spree
  module Api
    module V3
      module Admin
        # One figure of a reporting result, as the adapter reports it
        # (`{ value:, previous:, growth: }`), written for the wire by the
        # metric and currency passed in `params`.
        class ReportingMetricValueSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize value: [%i[string number], nullable: true,
                                              comment: 'A decimal string for money, decimal and percent metrics (`"110.00"`); a number for integer ' \
                                                       'metrics. Null in `totals` for a metric that only means something per group.'],
                   previous: [%i[string number], comment: 'Present when the query requested a comparison; the same shape as `value`.'],
                   growth: [:string, nullable: true,
                                     comment: 'Percentage change against the previous period, as a decimal string (`"12.5"`); null when ' \
                                              'there is no baseline. Present when the query requested a comparison.'],
                   display: [:string, comment: '`value` formatted with its currency symbol. Present on money metrics only.']

          # @param payloads [Hash{Symbol => Hash}] adapter payloads by metric name
          # @param currency [::Money::Currency] the result's currency
          # @return [Hash{Symbol => Hash}]
          def self.keyed(payloads, currency:)
            payloads.to_h do |name, payload|
              [name, new(payload, params: { metric: Spree.reporting.metrics.fetch(name), currency: currency }).to_h]
            end
          end

          attribute :value do |payload|
            params[:metric].format_value(payload[:value], params[:currency])
          end

          attribute :previous, if: proc { |payload| payload.key?(:previous) } do |payload|
            params[:metric].format_value(payload[:previous], params[:currency])
          end

          attribute :growth, if: proc { |payload| payload.key?(:growth) } do |payload|
            Spree::Money::Rounding.format_decimal(payload[:growth])
          end

          attribute :display, if: proc { params[:metric].money? } do |payload|
            Spree::Money.new(payload[:value], currency: params[:currency]).to_s
          end
        end
      end
    end
  end
end
