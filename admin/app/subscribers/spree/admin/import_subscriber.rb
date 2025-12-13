# frozen_string_literal: true

module Spree
  module Admin
    # Handles Import events for the admin interface.
    #
    # This subscriber listens to import.complete event and handles:
    # - Updating the loader in the import view (Turbo Streams)
    #
    # We use async: false because the UI update should happen immediately
    # after the import completes.
    #
    class ImportSubscriber < Spree::Subscriber
      subscribes_to 'import.complete', async: false

      on 'import.complete', :update_loader_in_import_view

      def update_loader_in_import_view(event)
        import_id = event.payload['id']
        return unless import_id

        import = Spree::Import.find_by(id: import_id)
        return unless import
        return unless import.respond_to?(:broadcast_update_to)

        import.broadcast_update_to(
          "import_#{import.id}_loader",
          target: 'loader',
          partial: 'spree/admin/imports/loader',
          locals: { import: import }
        )
      end
    end
  end
end
