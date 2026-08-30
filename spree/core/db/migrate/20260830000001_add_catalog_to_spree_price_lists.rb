class AddCatalogToSpreePriceLists < ActiveRecord::Migration[8.1]
  def change
    # nil = standalone list, matched by its own rules; set = owned by exactly
    # one catalog and reached only through it
    # (docs/plans/6.0-catalog-agreement-rework.md).
    add_reference :spree_price_lists, :catalog, index: false

    if ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      # MySQL ignores the +where:+ option, so it gets a plain index and the
      # one-live-list-per-catalog rule rests on the model validation.
      add_index :spree_price_lists, :catalog_id
    else
      # Partial unique index: one live list per catalog. Soft-deleted lists
      # keep their catalog_id as the restore path without blocking a
      # replacement list.
      add_index :spree_price_lists, :catalog_id, unique: true,
                where: 'catalog_id IS NOT NULL AND deleted_at IS NULL',
                name: 'index_spree_price_lists_one_per_catalog'
    end
  end
end
