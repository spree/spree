module Spree
  module Imports
    # Marks the import as working through its rows.
    class StartProcessing < Spree::Workflow
      hooks :validate, :after_start_processing

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_processing
          run_hooks :after_start_processing
        end

        success(import)
      end

      private

      def mark_processing
        failure(import) unless import.update(status: 'processing')
      end
    end
  end
end
