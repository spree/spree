class AddStatusToSpreeVariants < ActiveRecord::Migration[8.1]
  def change
    # No database default: the status is set by whatever creates the row —
    # `active` for a first-party variant through the attribute default,
    # `draft` for a seller's offer through the seller branch
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    #
    # Nullable so existing rows survive the migration; the
    # `spree:upgrade:variants_status` task backfills them to `active`, after
    # which every row a workflow writes carries one.
    add_column :spree_variants, :status, :string

    add_index :spree_variants, [:product_id, :status]
  end
end
