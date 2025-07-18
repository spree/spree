module Spree
  module Imports
    class ExecuteJob < Spree::BaseJob
      discard_on ActiveRecord::RecordNotFound

      def perform(import_id)
        import = Spree::Import.find(import_id)
        
        Spree::ImportService::Execute.new(import: import).call
      end
    end
  end
end
