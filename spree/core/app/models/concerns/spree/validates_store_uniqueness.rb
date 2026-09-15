module Spree
  # Declares an attribute unique within its store, ignoring rows that are gone.
  # Included in {Spree::Base}, so any model can declare one directly:
  #
  #   validates_store_uniqueness :name
  #   validates_store_uniqueness :name, scope: [:seller_id]
  #   validates_store_uniqueness :name, soft_delete_column: :revoked_at
  #
  # Nothing here resolves a record from a string — finding one by a slug or
  # permalink is FriendlyId's job.
  module ValidatesStoreUniqueness
    extend ActiveSupport::Concern

    class_methods do
      # @param attribute [Symbol] the column to keep unique
      # @param soft_delete_column [Symbol] the column a removed row is stamped
      #   with, so removed rows free their value. Defaults to `deleted_at`;
      #   a model without that column simply has none, and every row counts.
      # @param scope [Array<Symbol>] extra columns the value is unique within,
      #   e.g. `:seller_id` on a table sellers share with the operator
      def validates_store_uniqueness(attribute, soft_delete_column: :deleted_at, scope: [])
        # Resolved inside the lambda, not here: reading `column_names` while
        # the class body runs would hit the database during boot.
        conditions = lambda do
          klass = respond_to?(:klass) ? self.klass : self
          if klass.column_names.include?(soft_delete_column.to_s)
            where(soft_delete_column => nil)
          else
            all
          end
        end

        uniqueness_scope = [*spree_base_uniqueness_scope, :store_id, *scope]

        validates attribute,
                  uniqueness: { case_sensitive: false,
                                scope: uniqueness_scope,
                                conditions: conditions },
                  # Checked only when the value or the scope it is unique
                  # within changes — moving a delivery method to another
                  # seller has to be checked too. A row that already shares
                  # its value with another (from before this rule) stays
                  # saveable until the follow-up adds the unique index and
                  # renames existing duplicates.
                  if: lambda { |record|
                    [attribute, *uniqueness_scope].any? do |column|
                      record.will_save_change_to_attribute?(column)
                    end
                  }
      end
    end
  end
end
