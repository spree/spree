module Spree
  module SampleData
    # Creates the `Spree::Import` record for a sample CSV, attaching the file
    # but processing nothing — the two runners differ only in what they do next.
    class ImportBuilder
      # @return [Spree::Import] persisted, unprocessed
      def self.call(csv_path:, import_class:, store: nil, user: nil, inline: false, skip_events: false)
        store ||= Spree::Store.default
        # An admin of the target store, not `admin_user_class.first` — in a
        # multi-store or multi-tenant app that global first can belong to a
        # different store entirely.
        user ||= store.users.first

        raise 'No admin user found for the store. Complete first-run setup, or seed with ADMIN_EMAIL/ADMIN_PASSWORD set.' unless user

        import = import_class.new(owner: store, user: user)
        # Persisted before save: the processing jobs reload the record, so these
        # have to travel with it rather than live on the instance.
        import.preferred_inline = inline
        import.preferred_skip_events = skip_events
        # Saved with `validate: false` below, which skips the before_validation
        # that normally numbers the record.
        import.generate_number
        import.attachment.attach(
          io: File.open(csv_path),
          filename: File.basename(csv_path),
          content_type: 'text/csv'
        )
        import.save!(validate: false)
        import
      end
    end
  end
end
