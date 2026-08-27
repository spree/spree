class UnifyImportAndExportTenancy < ActiveRecord::Migration[8.1]
  def change
    # Imports and exports are the same kind of record — a bulk job over a
    # store's data, optionally run by one of its sellers — but they had drifted
    # into two different shapes. An export carried `store_id` (plus a
    # `belongs_to :seller` whose column was never created, so filtering an
    # export by seller raised); an import carried a polymorphic `owner` that
    # was a Store or a Seller but never both.
    #
    # Neither shape could answer the operator's question. A polymorphic owner
    # holding a seller loses the store, so the marketplace's own list could not
    # include its sellers' imports; and an export's seller was unaskable.
    #
    # Both tables now carry the same two axes: which marketplace this belongs
    # to, and — when someone other than the operator ran it — whose it is.
    # `store_id` is always present; a null `seller_id` means the operator's own.
    add_reference :spree_imports, :store, index: true
    add_reference :spree_imports, :seller, index: true

    # `spree_exports.seller_id` arrives with AddSellerToSpreeExports, which
    # landed alongside seller exports — this migration only has to bring
    # imports up to the shape exports already had.

    # The operator's list is store-scoped and reads both axes; a seller's is
    # narrowed to their own rows and to the types they may run.
    add_index :spree_imports, [:store_id, :seller_id]
    add_index :spree_exports, [:store_id, :seller_id]

    # `owner_type`/`owner_id` survive to 6.1 as the backfill's source and its
    # rollback path, and `Import#owner` keeps reading through them for one
    # release. `null: false` on the new store_id waits for the same release,
    # once spree:upgrade:backfill_import_export_tenancy has run everywhere.
    #
    # Their NOT NULL has to go now, though: nothing writes the pair any more,
    # so leaving it would make every new import fail to insert.
    change_column_null :spree_imports, :owner_type, true
    change_column_null :spree_imports, :owner_id, true
  end
end
