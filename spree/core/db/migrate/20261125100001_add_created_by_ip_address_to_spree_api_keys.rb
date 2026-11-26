# Where the request that created a key came from, shown in the security notice
# sent to store admins. Encrypted by Spree::ApiKey when encryption keys exist.
class AddCreatedByIpAddressToSpreeApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_api_keys, :created_by_ip_address, :string
  end
end
