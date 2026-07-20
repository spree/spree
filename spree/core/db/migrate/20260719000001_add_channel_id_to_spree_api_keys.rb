class AddChannelIdToSpreeApiKeys < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_api_keys, :channel, null: true, if_not_exists: true
  end
end
