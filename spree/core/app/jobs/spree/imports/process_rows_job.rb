module Spree
  module Imports
    # @deprecated Use {Spree::Imports::ProcessJob} with skip_row_creation:
    #   true; removed in 6.1.
    class ProcessRowsJob < Spree::Imports::BaseJob
      def perform(import_id)
        Spree::Deprecation.warn('Spree::Imports::ProcessRowsJob is deprecated and will be removed in Spree 6.1. Use Spree::Imports::ProcessJob instead.')
        Spree::Imports::ProcessJob.perform_now(import_id, skip_row_creation: true)
      end
    end
  end
end
