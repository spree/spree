# frozen_string_literal: true

module Spree
  module Admin
    # Handles ImportRow events for the admin interface.
    #
    # This subscriber listens to import_row.completed and import_row.failed events
    # and handles:
    # - Adding the row to the import view (Turbo Streams)
    # - Updating the footer in the import view (Turbo Streams)
    #
    # We use async: false because the UI updates should happen immediately.
    #
    class ImportRowSubscriber < Spree::Subscriber
      subscribes_to 'import_row.completed', 'import_row.failed', async: false

      on 'import_row.completed', :update_import_view
      on 'import_row.failed', :update_import_view

      def update_import_view(event)
        import_row_id = event.payload['id']
        return unless import_row_id

        import_row = Spree::ImportRow.find_by_prefix_id(import_row_id)
        return unless import_row

        add_row_to_import_view(import_row)
        update_footer_in_import_view(import_row)
      end

      private

      def add_row_to_import_view(import_row)
        return unless import_row.respond_to?(:broadcast_append_to)

        # we need to render this partial with store context to properly generate image URLs
        with_store_context(import_row) do
          import_row.broadcast_append_to(
            "import_#{import_row.import_id}_rows",
            target: 'rows',
            partial: 'spree/admin/imports/row',
            locals: { row: import_row, import: import_row.import }
          )
        end
      end

      def update_footer_in_import_view(import_row)
        return unless import_row.respond_to?(:broadcast_replace_to)

        import_row.broadcast_replace_to(
          "import_#{import_row.import_id}_footer",
          target: 'footer',
          partial: 'spree/admin/imports/footer',
          locals: { import: import_row.import }
        )
      end

      def with_store_context(import_row)
        store = import_row.store
        Spree::Current.store = store
        Rails.application.routes.default_url_options[:host] = store.url_or_custom_domain
        yield
      ensure
        Spree::Current.reset if defined?(Spree::Current)
      end
    end
  end
end
