class CreateSpreeWebhooksTables < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_webhooks_endpoints do |t|
      t.string :url, null: false
      t.boolean :enabled, default: false, index: true

      if t.respond_to? :jsonb
        t.jsonb :subscriptions
      else
        t.json :subscriptions
      end

      t.timestamps
    end
  end
end
