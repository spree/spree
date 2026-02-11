require 'csv'

module Spree
  module SampleData
    class ImportRunner
      prepend Spree::ServiceModule::Base

      def call(csv_path:, import_class:)
        store = Spree::Store.default
        admin = Spree.admin_user_class.first

        raise 'No admin user found. Please run seeds first.' unless admin

        import = import_class.new(
          owner: store,
          user: admin
        )
        import.number = import.generate_permalink(import_class)
        import.attachment.attach(
          io: File.open(csv_path),
          filename: File.basename(csv_path),
          content_type: 'text/csv'
        )
        import.save!(validate: false)
        import.update_columns(status: 'processing')
        import.create_mappings

        row_number = 0
        failed = 0

        ::CSV.foreach(csv_path, headers: true) do |csv_row|
          row_number += 1
          import_row = import.rows.create!(
            row_number: row_number,
            data: csv_row.to_h.to_json,
            status: 'pending'
          )

          begin
            import_row.process!
          rescue StandardError => e
            failed += 1
            puts "\n  Warning: Row #{row_number} failed: #{e.message}"
          end
        end

        import.update!(status: 'completed')
        puts "  Processed #{row_number} rows (#{failed} failed)"
      end
    end
  end
end
