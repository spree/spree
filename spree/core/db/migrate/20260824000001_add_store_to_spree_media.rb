class AddStoreToSpreeMedia < ActiveRecord::Migration[8.1]
  def change
    # Which store owns this file.
    #
    # Media used to derive its tenancy from its viewable — a row belonged to a
    # product, and the product belonged to a store. The library breaks that
    # chain: a file uploaded before anyone has decided where it goes has no
    # viewable at all, so there is nothing to derive the answer from and no way
    # to scope the library index without it.
    #
    # Existing rows are filled in by spree:upgrade:backfill_media_store_ids.
    # The NOT NULL constraint waits for 6.1, once that task has had a release
    # to run everywhere.
    add_reference :spree_media, :store, index: true
  end
end
