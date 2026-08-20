module Spree
  module Imports
    # Accepts the column mapping and starts building rows from the file.
    #
    # Dispatch happens after the transaction rather than inside it: the job
    # reads the import back, so it must not start before the status is
    # visible to another connection.
    class CompleteMapping < Spree::Workflow
      hooks :validate, :after_complete_mapping

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        step :ensure_mapping
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_completed_mapping
          run_hooks :after_complete_mapping
        end

        step :dispatch_row_creation
        success(import)
      end

      private

      def ensure_mapping
        failure(import, :import_not_mapping) unless import.status == 'mapping'
      end

      def mark_completed_mapping
        failure(import) unless import.update(status: 'completed_mapping')
      end

      # Inline runs are for rake tasks, seeds and the console, where the data
      # has to exist by the time the call returns and there may be no worker.
      def dispatch_row_creation
        if import.preferred_inline
          Spree::Imports::ProcessJob.perform_now(import.id)
        else
          # The short delay lets the attachment settle before the job reads it.
          Spree::Imports::ProcessJob.set(wait: 2.seconds).perform_later(import.id)
        end
      end
    end
  end
end
