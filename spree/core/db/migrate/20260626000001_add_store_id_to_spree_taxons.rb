class AddStoreIdToSpreeTaxons < ActiveRecord::Migration[7.2]
  # NOTE: After running this migration, existing taxons have +store_id IS NULL+
  # and keep resolving their store through their taxonomy (Taxon.for_store falls
  # back to the taxonomy join). Run the backfill to populate +store_id+ directly,
  # which is what taxonomy-less categories (Spree::Category) rely on:
  #
  #   bundle exec rake spree:taxons:backfill_store_id
  def change
    add_reference :spree_taxons, :store, null: true, if_not_exists: true
  end
end
