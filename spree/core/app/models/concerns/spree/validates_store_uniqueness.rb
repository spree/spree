module Spree
  # Per-store uniqueness for an attribute, ignoring rows that are gone.
  # Included in {Spree::Base}, so any model can declare one directly:
  #
  #   validates_store_uniqueness :name
  #   validates_store_uniqueness :name, scope: [:seller_id]
  #   validates_store_uniqueness :name, live: :revoked_at
  #
  # The per-store counterpart of {Spree::UniqueName} (globally unique names)
  # and the general form of {Spree::NamedType} (which fixes the attribute at
  # `name`). Nothing here resolves a record from a string — finding one by a
  # slug or permalink is FriendlyId's job.
  module ValidatesStoreUniqueness
    extend ActiveSupport::Concern

    class_methods do
      # @param attribute [Symbol] the column to keep unique
      # @param live [Symbol] the column that is nil while the row counts —
      #   `deleted_at` for soft-deleted models, `revoked_at` for API keys
      # @param scope [Array<Symbol>] extra columns the value is unique within,
      #   e.g. `:seller_id` on a table sellers share with the operator
      def validates_store_uniqueness(attribute, live: :deleted_at, scope: [])
        validates attribute,
                  uniqueness: { case_sensitive: false,
                                scope: [*spree_base_uniqueness_scope, :store_id, *scope],
                                conditions: -> { where(live => nil) } },
                  # Checked only when the attribute changes, so a row that
                  # already shares its value with another (from before this
                  # rule) can still be saved. Removed once the follow-up adds
                  # the unique index and renames existing duplicates.
                  if: :"will_save_change_to_#{attribute}?"
      end
    end
  end
end
