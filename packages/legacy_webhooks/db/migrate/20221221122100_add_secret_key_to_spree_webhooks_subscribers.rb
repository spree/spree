class AddSecretKeyToSpreeWebhooksSubscribers < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_webhooks_subscribers, :secret_key, :string, null: true
  end
end
