module Spree
  module TestingSupport
    module Imports
      # Builds an import's column mappings without moving it out of whatever
      # status the example put it in. Spree::Imports::StartMapping does both,
      # which is right for the pipeline but wrong for a spec that starts an
      # import mid-flight.
      def seed_import_mappings(import)
        status_before = import.status
        Spree.import_start_mapping_workflow.call(import: import)
        import.update_columns(status: status_before, updated_at: Time.current)
        import.reload
      end
    end
  end
end
