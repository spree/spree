module Spree
  module Imports
    class ProcessRowsJob < Spree::BaseJob
      queue_as Spree.queues.imports

      def perform(import_id)
        import = Spree::Import.find(import_id)

        import.rows.pending_and_failed.find_each(batch_size: 100) do |row|
          row.process!
        end
      end
    end
  end
end
