module Spree
  module Api
    module V3
      module Admin
        # What a reporting result answers: the resolved currency, periods,
        # metrics and dimensions of the query that produced it.
        class ReportingResultMetaSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize currency: :string, metrics: [:string, multi: true]

          attributes :currency

          typelize({ since: :string, until: :string }, comment: 'The period queried, as ISO 8601 times.')
          attribute :time_range do |meta|
            iso_range(meta[:time_range])
          end

          typelize({ since: :string, until: :string }, nullable: true,
                                                       comment: 'The period compared against; null without `compare`.')
          attribute :previous_time_range do |meta|
            iso_range(meta[:previous_time_range])
          end

          attributes :metrics

          typelize({ name: :string, grain: [:string, optional: true] }, multi: true)
          attribute :dimensions do |meta|
            meta[:dimensions]
          end

          private

          def iso_range(range)
            return unless range

            { since: range.first.iso8601, until: range.last.iso8601 }
          end
        end
      end
    end
  end
end
