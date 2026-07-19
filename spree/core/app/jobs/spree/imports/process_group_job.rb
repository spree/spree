module Spree
  module Imports
    class ProcessGroupJob < Spree::Imports::BaseJob
      # A large import fans out into many group jobs; without a cap they
      # occupy every worker thread as one frees up, starving checkout-critical
      # queues that share the pool. Cap concurrent groups per import at 75%
      # of JOB_THREADS (at least 1), or SPREE_IMPORT_JOB_CONCURRENCY when set
      # (0 disables the cap) — excess jobs wait as blocked executions, not in
      # worker threads. Both values are read by the process enqueueing the
      # import, so on a split web/worker deployment set the explicit override
      # on the web service. The semaphore duration must outlive the slowest
      # group; expiry just lifts the cap, it doesn't lose jobs. Solid
      # Queue-specific (no-op on other adapters).
      import_concurrency = ENV['SPREE_IMPORT_JOB_CONCURRENCY'].presence&.to_i ||
        [Integer(ENV.fetch('JOB_THREADS', 3)) * 3 / 4, 1].max
      if import_concurrency.positive? && respond_to?(:limits_concurrency)
        limits_concurrency to: import_concurrency, key: ->(import_id, _row_ids) { import_id }, duration: 30.minutes
      end

      # Rows are loaded in slices so a large group never holds every ImportRow
      # (and its raw CSV data) in memory for the whole job.
      ROWS_BATCH_SIZE = 100

      def perform(import_id, row_ids)
        import = Spree::Import.find(import_id)
        Spree::Current.store = import.store

        mappings = import.mappings.mapped.to_a
        schema_fields = import.schema_fields
        large = import.large_import?
        grouped = import.group_column.present? && mappings.any? { |m| m.schema_field == import.group_column }
        started_at = Time.current
        processed_rows = []

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
          elsif grouped
            # A group is one product plus its variants: per-record lifecycle
            # events (variant.created, price.created, product.updated per
            # touch) are noise to subscribers — one product event is published
            # for the whole group below. import_row.* events still flow.
            Spree::Events.disable_lifecycle do
              rows.each { |row| row.process!(mappings: mappings, schema_fields: schema_fields) }
            end
          else
            rows.each do |row|
              row.process!(mappings: mappings, schema_fields: schema_fields)
            end
          end
          processed_rows.concat(rows)
        end

        publish_group_events(processed_rows, started_at) if grouped
        check_import_completion(import, large)
      end

      private

      # One event per product touched by this group: `product.created` when the
      # product came into existence during this run, `product.updated` otherwise
      # (including retries of a group whose first attempt created it).
      def publish_group_events(rows, started_at)
        products = rows.select { |row| row.status == 'completed' }.filter_map do |row|
          item = row.item
          next item if item.is_a?(Spree::Product)

          item.product if item.respond_to?(:product)
        end.uniq

        products.each do |product|
          event = product.created_at >= started_at ? 'product.created' : 'product.updated'
          product.publish_event(event)
        end
      end

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
