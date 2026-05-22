module Spree
  module Imports
    class ProcessGroupJob < Spree::BaseJob
      queue_as Spree.queues.imports

      # Narrow retry to transient infrastructure errors so we don't replay jobs whose
      # check_import_completion side effects (counter bump, complete!, events) have
      # already partially fired. Per-row exceptions are caught inside ImportRow#process!
      # and converted to row.fail!, so they never bubble up here.
      retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
               ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
               wait: :polynomially_longer, attempts: 5
      discard_on ActiveJob::DeserializationError

      def perform(import_id, row_ids)
        import = Spree::Import.find(import_id)
        Spree::Current.store = import.store

        mappings = import.mappings.mapped.to_a
        schema_fields = import.schema_fields
        large = import.large_import?
        # Skip rows already completed on a prior attempt so retries don't double-process them.
        rows = import.rows.where(id: row_ids).pending_and_failed.order(:row_number)

        if large
          Spree::Events.disable do
            rows.each { |row| row.bulk_process!(mappings: mappings, schema_fields: schema_fields) }
          end
        else
          rows.each do |row|
            row.process!(mappings: mappings, schema_fields: schema_fields)
          end
        end

        check_import_completion(import, large)
      end

      private

      # Completion is row-state-derived so retry-induced over-increments of the counter
      # stay harmless. The counter pre-check just shortcuts the row scan for workers
      # that obviously can't be the last group to finish.
      def check_import_completion(import, large)
        Spree::Import.where(id: import.id).update_all(
          'completed_groups_count = COALESCE(completed_groups_count, 0) + 1'
        )
        import.reload

        if import.completed_groups_count >= import.processing_groups_count && import.rows.unprocessed.none?
          import.complete! if import.status == 'processing'
        elsif large && (import.completed_groups_count % 10).zero?
          import.publish_event('import.progress')
        end
      end
    end
  end
end
