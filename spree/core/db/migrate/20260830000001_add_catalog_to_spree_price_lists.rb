class AddCatalogToSpreePriceLists < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_spree_price_lists_one_per_catalog'.freeze

  def change
    # nil = standalone list, matched by its own rules; set = owned by exactly
    # one catalog and reached only through it
    # (docs/plans/6.0-catalog-agreement-rework.md).
    add_reference :spree_price_lists, :catalog, index: false

    add_catalog_uniqueness_index
  end

  private

  # One live list per catalog. Soft-deleted lists release the slot, so a
  # catalog whose list was deleted can be given a replacement.
  #
  # Written per adapter because only PostgreSQL and SQLite have partial
  # indexes. MySQL and MariaDB instead index a stored generated column holding
  # the catalog only while the row is live, so a deleted list drops out of the
  # index altogether — NULLs compare distinct there, which is also what lets a
  # standalone list (catalog_id NULL) sit alongside any number of others.
  # Expression per the spree_commission_rates precedent: the one form both
  # MySQL 8 and MariaDB 11 accept.
  def add_catalog_uniqueness_index
    if Spree.mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_price_lists
            ADD COLUMN catalog_key BIGINT
            AS (IF(deleted_at IS NULL, catalog_id, NULL)) STORED
          SQL
          add_index :spree_price_lists, :catalog_key, unique: true, name: INDEX_NAME
        end

        dir.down do
          remove_index :spree_price_lists, name: INDEX_NAME
          remove_column :spree_price_lists, :catalog_key
        end
      end
    else
      add_index :spree_price_lists, :catalog_id, unique: true,
                where: 'catalog_id IS NOT NULL AND deleted_at IS NULL', name: INDEX_NAME
    end
  end
end
