module Spree
  module Exports
    class GenerateJob < Spree::BaseJob
      queue_as Spree.queues.exports

      def perform(export_id)
        export = Spree::Export.find_by_prefix_id!(export_id)
        export.generate
      end
    end
  end
end
