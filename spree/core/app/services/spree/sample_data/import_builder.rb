module Spree
  module SampleData
    # Creates the `Spree::Import` record for a sample CSV, attaching the file
    # but processing nothing — the two runners differ only in what they do next.
    class ImportBuilder
      # @return [Spree::Import] persisted, unprocessed
      def self.call(csv_path:, import_class:, store: nil, user: nil)
        store ||= Spree::Store.default
        # An admin of the target store, not `admin_user_class.first` — in a
        # multi-store or multi-tenant app that global first can belong to a
        # different store entirely.
        user ||= store.users.first

        raise 'No admin user found. Please run seeds first.' unless user

        import = import_class.new(owner: store, user: user)
        import.number = import.generate_permalink(import_class)
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
