module Spree
  module Imports
    # Runs the failed rows of a finished import again. The dispatcher already
    # targets pending and failed rows, so this is a status move plus a
    # re-dispatch — the successful rows are left alone.
    class RetryFailedRows < Spree::Workflow
      hooks :validate, :after_retry

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        step :ensure_retryable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_processing
          run_hooks :after_retry
        end

        step :dispatch_rows
        success(import)
      end

      private

      def ensure_retryable
        failure(import, :import_not_completed) unless import.status == 'completed'
        failure(import, :import_has_no_failed_rows) unless import.rows.failed.exists?
      end

      def mark_processing
        failure(import) unless import.update(status: 'processing')
      end

      def dispatch_rows
        if import.preferred_inline
          Spree::Imports::ProcessJob.perform_now(import.id, skip_row_creation: true)
        else
          Spree::Imports::ProcessJob.perform_later(import.id, skip_row_creation: true)
        end
      end
    end
  end
end
