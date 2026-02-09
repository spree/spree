# This migration comes from spree (originally 20230512094803)
class RenameDataFeedsColumnProviderToType < ActiveRecord::Migration[6.1]
  def change
    rename_column :spree_data_feeds, :provider, :type
  end
end
