module Spree
  module Imports
    class CreateRowsJob < Spree::BaseJob
      queue_as Spree.queues.imports

      BATCH_SIZE = 1000

      def perform(import_id)
        import = Spree::Import.find(import_id)

        process_csv_sequentially(import)

        # Mark as processed when complete
        import.processed!
      end

      private

      def process_csv_sequentially(import)
        rows_to_insert = []
        row_number = 1

        created_at = updated_at = Time.current

        # Stream CSV to avoid loading entire file in memory
        # This maintains order by processing sequentially
        ::CSV.foreach(StringIO.new(import.attachment_file_content),
                   headers: true,
                   col_sep: import.delimiter,
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
            Spree::ImportRow.upsert_all(rows_to_insert)
            rows_to_insert.clear
          end
        end

        # Upsert any remaining rows
        if rows_to_insert.any?
          Spree::ImportRow.upsert_all(rows_to_insert)
        end
      end
    end
  end
end
