# frozen_string_literal: true

module Spree
  module Admin
    # Handles Import events for the admin interface.
    #
    # We use async: false because the UI updates should happen immediately.
    #
    class ImportSubscriber < Spree::Subscriber
      subscribes_to 'import.completed', 'import.progress', async: false

      on 'import.completed', :update_loader_in_import_view
      on 'import.progress', :update_footer_in_import_view

      def update_loader_in_import_view(event)
        import = find_import(event)
        return unless import

        import.broadcast_update_to(
          "import_#{import.id}_loader",
          target: 'loader',
          partial: 'spree/admin/imports/loader',
          locals: { import: import }
        )
      end

      def update_footer_in_import_view(event)
        import = find_import(event)
        return unless import

        import.broadcast_replace_to(
          "import_#{import.id}_footer",
          target: 'footer',
          partial: 'spree/admin/imports/footer',
          locals: { import: import }
        )
      end

      private

      def find_import(event)
        import_id = event.payload['id']
        return unless import_id

        Spree::Import.find_by_prefix_id(import_id)
      end
    end
  end
end
