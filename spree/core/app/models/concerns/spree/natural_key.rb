module Spree
  # Declares the attribute a configuration file addresses records of this
  # model by (`spree config`, docs/plans/6.0-cli-configurator.md): unique
  # among a store's live rows, compared case-insensitively.
  #
  # Checked only when the attribute changes, so a row that already shared
  # its key with another (from before the rule) can still be saved until the
  # follow-up that adds the unique index and renames duplicates.
  module NaturalKey
    extend ActiveSupport::Concern

    class_methods do
      # @param attribute [Symbol] the key column
      # @param live [Symbol] the column that is nil while the row counts —
      #   `deleted_at` for soft-deleted models, `revoked_at` for API keys
      # @param scope [Array<Symbol>] extra columns the key is unique within,
      #   e.g. `:seller_id` on a table sellers share
      def natural_key(attribute, live: :deleted_at, scope: [])
        validates attribute,
                  uniqueness: { case_sensitive: false,
                                scope: [*spree_base_uniqueness_scope, :store_id, *scope],
                                conditions: -> { where(live => nil) } },
                  if: :"will_save_change_to_#{attribute}?"
      end
    end
  end
end
