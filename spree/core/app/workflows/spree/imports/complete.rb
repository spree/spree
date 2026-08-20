module Spree
  module Imports
    # Closes out an import once every row has been processed.
    class Complete < Spree::Workflow
      hooks :validate, :after_complete

      # @param import [Spree::Import]
      # @return [Spree::ServiceModule::Result] value is the import
      def perform(import:)
        super

        step :ensure_processing
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_completed
          step :touch_store
          run_hooks :after_complete
        end

        import.publish_event('import.completed')
        success(import)
      end

      private

      # Only an import that is working through its rows can finish. Without
      # this a failed or half-mapped import would flip to completed, touch the
      # store and announce itself as done.
      def ensure_processing
        failure(import, :import_not_processing) unless import.status == 'processing'
      end

      def mark_completed
        failure(import) unless import.update(status: 'completed')
      end

      # An import changes the catalog, so the store's cache keys have to move
      # with it.
      def touch_store
        import.store.touch
      end
    end
  end
end
