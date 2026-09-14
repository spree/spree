module Spree
  # Declares an attribute unique within its store, ignoring rows that are gone.
  # Included in {Spree::Base}, so any model can declare one directly:
  #
  #   unique_per_store :name
  #   unique_per_store :name, scope: [:seller_id]
  #   unique_per_store :url, live: :revoked_at
  #
  # Nothing here resolves a record from a string — finding one by a slug or
  # permalink is FriendlyId's job.
  module UniquePerStore
    extend ActiveSupport::Concern

    class_methods do
      # @param attribute [Symbol] the column to keep unique
      # @param live [Symbol, nil] the column that is nil while the row counts —
      #   `deleted_at` for soft-deleted models, `revoked_at` for API keys, and
      #   nil for a model whose rows are deleted outright
      # @param scope [Array<Symbol>] extra columns the value is unique within,
      #   e.g. `:seller_id` on a table sellers share with the operator
      def unique_per_store(attribute, live: :deleted_at, scope: [])
        # Resolved inside the lambda, not here: reading `column_names` while
        # the class body runs would hit the database during boot.
        conditions = lambda do
          klass = respond_to?(:klass) ? self.klass : self
          live && klass.column_names.include?(live.to_s) ? where(live => nil) : all
        end

        validates attribute,
                  uniqueness: { case_sensitive: false,
                                scope: [*spree_base_uniqueness_scope, :store_id, *scope],
                                conditions: conditions },
                  # Checked only when the attribute changes, so a row that
                  # already shares its value with another (from before this
                  # rule) can still be saved. Removed once the follow-up adds
                  # the unique index and renames existing duplicates.
                  if: :"will_save_change_to_#{attribute}?"
      end
    end
  end
end
