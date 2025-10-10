module Spree
  module Exports
    class GenerateJob < Spree::BaseJob
      queue_as Spree.queues.exports

      def perform(export_id)
        export = Spree::Export.find(export_id)
        export.generate
      end
    end
  end
end
