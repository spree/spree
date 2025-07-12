require 'csv'

module Spree
  module ImportService
    class Execute
      def initialize(import:)
        @import = import
      end

      def call
        reset_import_details
        read_file
      ensure
        import.update(processed_at: DateTime.current)
      end

      private

      attr_reader :import

      def read_file
        file.open do |tmp_file|
          ::CSV.foreach(tmp_file, headers: true).with_index(1) do |row, index|
            begin
              process_row_factory.new(row: row.to_h).call
              import.processed_count = import.processed_count + 1
            rescue Spree::ImportService::Error => error
              import.error_details = import.error_details.merge!(error.to_h)
            ensure
              import.update!(total_count: index)
            end
          end
        end
      end

      def reset_import_details
        import.assign_attributes(
          error_details: {},
          processed_count: 0,
          processed_at: nil
        )
      end

      def file
        @file ||= import.attachment.attachment
      end

      def process_row_factory
        @process_row_factory ||= case import.type
        when 'Spree::Imports::Products' then Spree::ImportService::Products::Upsert
        end
      end
    end
  end
end
