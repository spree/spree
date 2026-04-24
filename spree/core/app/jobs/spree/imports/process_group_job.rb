module Spree
  module Imports
    class ProcessGroupJob < Spree::BaseJob
      queue_as Spree.queues.imports

      def perform(import_id, row_ids)
        import = Spree::Import.find(import_id)
        Spree::Current.store = import.store

        mappings = import.mappings.mapped.to_a
        schema_fields = import.schema_fields
        large = import.large_import?
        rows = import.rows.where(id: row_ids).order(:row_number)

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

      def check_import_completion(import, large)
        Spree::Import.where(id: import.id).update_all(
          'completed_groups_count = COALESCE(completed_groups_count, 0) + 1'
        )
        import.reload

        if import.completed_groups_count >= import.processing_groups_count
          # Guard against concurrent workers both reaching this point
          import.complete! if import.status == 'processing'
        elsif large && (import.completed_groups_count % 10).zero?
          import.publish_event('import.progress')
        end
      end
    end
  end
end
