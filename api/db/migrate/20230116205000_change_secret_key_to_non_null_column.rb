class ChangeSecretKeyToNonNullColumn < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_webhooks_subscribers, :secret_key, false
  end
end
