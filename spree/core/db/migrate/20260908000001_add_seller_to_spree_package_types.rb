class AddSellerToSpreePackageTypes < ActiveRecord::Migration[8.1]
  MARKETPLACE_NAME_INDEX = 'index_spree_package_types_marketplace_name'.freeze
  SELLER_NAME_INDEX = 'index_spree_package_types_seller_name'.freeze
  MARKETPLACE_DEFAULT_INDEX = 'index_spree_package_types_marketplace_default'.freeze
  SELLER_DEFAULT_INDEX = 'index_spree_package_types_seller_default'.freeze
  STORE_NAME_INDEX = 'index_spree_package_types_on_store_and_name'.freeze
  DEFAULT_PER_STORE_INDEX = 'index_spree_package_types_default_per_store'.freeze

  def change
    # Whose packaging this is: a seller's own boxes and cartons, or (nil) the
    # marketplace's — the shared vocabulary every seller may pack into.
    add_reference :spree_package_types, :seller, null: true

    # Two indexes where there was one, because a nullable column inside a
    # unique index constrains nothing for the rows where it is null: the
    # marketplace's rows all share a NULL seller_id, and NULLs compare
    # distinct. MySQL has no partial indexes, so there the seller rows are
    # covered (they carry no NULL) and the marketplace's fall back to the
    # model validation — the arrangement the default flag already has.
    #
    # Spelled out per direction so the change rolls back: an index removed by
    # name alone cannot be inferred in reverse.
    reversible do |dir|
      dir.up { split_indexes_by_owner }
      dir.down { restore_store_wide_indexes }
    end
  end

  private

  def split_indexes_by_owner
    remove_index :spree_package_types, name: STORE_NAME_INDEX

    if supports_partial_index?
      add_index :spree_package_types, [:store_id, :name], unique: true,
                where: 'seller_id IS NULL', name: MARKETPLACE_NAME_INDEX
      add_index :spree_package_types, [:store_id, :seller_id, :name], unique: true,
                where: 'seller_id IS NOT NULL', name: SELLER_NAME_INDEX

      remove_index :spree_package_types, name: DEFAULT_PER_STORE_INDEX
      add_index :spree_package_types, :store_id, unique: true,
                where: '"default" = TRUE AND seller_id IS NULL', name: MARKETPLACE_DEFAULT_INDEX
      add_index :spree_package_types, [:store_id, :seller_id], unique: true,
                where: '"default" = TRUE AND seller_id IS NOT NULL', name: SELLER_DEFAULT_INDEX
    else
      add_index :spree_package_types, [:store_id, :seller_id, :name], unique: true,
                name: SELLER_NAME_INDEX
    end
  end

  # Rolling back means going back to one default and one name per store, so a
  # store holding a seller's packaging cannot satisfy either. Drop those rows
  # first: they are unreachable without the column this migration adds.
  def restore_store_wide_indexes
    execute("DELETE FROM spree_package_types WHERE seller_id IS NOT NULL")

    if supports_partial_index?
      remove_index :spree_package_types, name: SELLER_DEFAULT_INDEX
      remove_index :spree_package_types, name: MARKETPLACE_DEFAULT_INDEX
      add_index :spree_package_types, :store_id, unique: true,
                where: '"default" = TRUE', name: DEFAULT_PER_STORE_INDEX

      remove_index :spree_package_types, name: SELLER_NAME_INDEX
      remove_index :spree_package_types, name: MARKETPLACE_NAME_INDEX
    else
      remove_index :spree_package_types, name: SELLER_NAME_INDEX
    end

    add_index :spree_package_types, [:store_id, :name], unique: true, name: STORE_NAME_INDEX
  end

  # `Spree.mysql?` rather than a fresh adapter check: it matches Trilogy too,
  # which Rails reports as "Trilogy", and a hand-rolled /mysql/i test would
  # take the partial-index branch there and fail on a database that has none.
  def supports_partial_index?
    !Spree.mysql?
  end
end
