module Spree
  module Imports
    # Marks the import as working through its rows.
    class StartProcessing < Spree::Workflow
      hooks :validate, :after_start_processing

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        step :ensure_mapping_completed
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_processing
          run_hooks :after_start_processing
        end

        success(import)
      end

      private

      # Rows only exist once the mapping is accepted, so processing cannot
      # start before that.
      def ensure_mapping_completed
        failure(import, :import_mapping_not_completed) unless import.status == 'completed_mapping'
      end

      def mark_processing
        failure(import) unless import.update(status: 'processing')
      end
    end
  end
end
