module Spree
  module Imports
    class ProcessGroupJob < Spree::Imports::BaseJob
      # Rows are loaded in slices so a large group never holds every ImportRow
      # (and its raw CSV data) in memory for the whole job.
      ROWS_BATCH_SIZE = 100

      def perform(import_id, row_ids)
        import = Spree::Import.find(import_id)
        Spree::Current.store = import.store

        mappings = import.mappings.mapped.to_a
        schema_fields = import.schema_fields
        large = import.large_import?

        row_ids.each_slice(ROWS_BATCH_SIZE) do |ids|
          # Skip rows already completed on a prior attempt so retries don't double-process them.
          rows = import.rows.where(id: ids).pending_and_failed.order(:row_number).to_a
          # Share the already-loaded import across rows: each row's processor reads
          # `row.import` (store, ability, lookup cache), and without this every row
          # lazily loads its own Import instance and rebuilds all of that per row.
          rows.each { |row| row.association(:import).target = import }

          if large
            Spree::Events.disable do
              rows.each { |row| row.bulk_process!(mappings: mappings, schema_fields: schema_fields) }
            end
          else
            rows.each do |row|
              row.process!(mappings: mappings, schema_fields: schema_fields)
            end
          end
        end

        check_import_completion(import, large)
      end

      private

      # Completion is row-state-derived so retry-induced over-increments of the counter
      # stay harmless. The counter pre-check just shortcuts the row scan for workers
      # that obviously can't be the last group to finish. `in_flight` excludes orphaned
      # `processing` rows past the stall window so a dead worker can't block completion.
      def check_import_completion(import, large)
        Spree::Import.where(id: import.id).update_all(
          'completed_groups_count = COALESCE(completed_groups_count, 0) + 1'
        )
        import.reload

        if import.completed_groups_count >= import.processing_groups_count && import.rows.in_flight.none?
          import.complete! if import.status == 'processing'
        elsif large && (import.completed_groups_count % 10).zero?
          import.publish_event('import.progress')
        end
      end
    end
  end
end
