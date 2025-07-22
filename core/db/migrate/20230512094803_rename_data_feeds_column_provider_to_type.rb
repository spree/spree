class RenameDataFeedsColumnProviderToType < ActiveRecord::Migration[6.1]
  def change
    rename_column :spree_data_feeds, :provider, :type
  end
end
