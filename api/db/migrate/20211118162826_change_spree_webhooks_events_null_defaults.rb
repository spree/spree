class ChangeSpreeWebhooksEventsNullDefaults < ActiveRecord::Migration[5.2]
  def change
    change_column_null :spree_webhooks_events, :subscriber_id, true
    change_column_null :spree_webhooks_events, :url, true
  end
end
