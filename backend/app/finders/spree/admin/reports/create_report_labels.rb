module Spree
  module Admin
    module Reports
      class CreateReportLabels
        def call(from:, to:, mode:)
          (from..to).to_a
                    .map { |date| date.strftime(format(mode)) }
                    .uniq
        end

        private

        def format(mode)
          case mode.try(:to_sym)
          when :year
            '%Y'
          when :month
            '%Y-%m'
          else
            '%Y-%m-%d'
          end
        end
      end
    end
  end
end
