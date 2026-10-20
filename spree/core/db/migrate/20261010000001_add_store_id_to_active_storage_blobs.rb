# Records which store owns every uploaded file, so a file from one store cannot
# be attached in another and storage can be measured and cleaned up per store.
# Active Storage ignores columns it does not define. Existing rows are filled
# in by `spree:uploads:assign_stores` in the 6.0 upgrade.
class AddStoreIdToActiveStorageBlobs < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:active_storage_blobs)
    return if column_exists?(:active_storage_blobs, :store_id)

    add_reference :active_storage_blobs, :store, null: true, index: true
  end
end
