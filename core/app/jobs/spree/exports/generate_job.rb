module Spree
  module Exports
    class GenerateJob < Spree::BaseJob
      def perform(export_id)
        export = Spree::Export.find(export_id)
        export.generate
      end
    end
  end
end
