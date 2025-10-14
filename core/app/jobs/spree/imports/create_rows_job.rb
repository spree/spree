module Spree
  module Imports
    class CreateRowsJob < Spree::BaseJob
      queue_as Spree.queues.imports

      BATCH_SIZE = 1000

      def perform(import_id)
        import = Spree::Import.find(import_id)
        import.started_processing! unless import.processing?

        create_rows_sequentially(import)

        # enqueue processing rows job after creating rows in a separate job
        import.process_rows_async
      end

      private

      def create_rows_sequentially(import)
        rows_to_insert = []
        row_number = 1

        created_at = updated_at = Time.current

        upsert_options = {}
        if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' || ActiveRecord::Base.connection.adapter_name == 'SQLite'
          upsert_options[:unique_by] = %i[import_id row_number]
        end

        # Stream CSV to avoid loading entire file in memory
        # This maintains order by processing sequentially
        ::CSV.foreach(StringIO.new(import.attachment_file_content),
                   headers: true,
                   col_sep: import.preferred_delimiter,
                   encoding: 'UTF-8') do |csv_row|

          rows_to_insert << {
            import_id: import.id,
            row_number: row_number,
            data: csv_row.to_h.to_json,
            status: 'pending',
            created_at: created_at,
            updated_at: updated_at
          }

          row_number += 1

          # Bulk upsert when we reach batch size
          if rows_to_insert.size >= BATCH_SIZE
            Spree::ImportRow.upsert_all(rows_to_insert, **upsert_options)
            rows_to_insert.clear
          end
        end

        # Upsert any remaining rows
        if rows_to_insert.any?
          Spree::ImportRow.upsert_all(rows_to_insert, **upsert_options)
        end
      end
    end
  end
end
