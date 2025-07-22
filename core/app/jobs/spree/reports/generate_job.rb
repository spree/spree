module Spree
  module Reports
    class GenerateJob < Spree::BaseJob
      queue_as Spree.queues.reports

      def perform(report_id)
        report = Spree::Report.find(report_id)
        report.generate
      end
    end
  end
end
