class CreateSpreeWebhooksTables < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_webhooks_endpoints do |t|
      t.string :url, null: false
      t.boolean :enabled, default: false, index: true

      create_subscriptions_column!(t)

      t.timestamps
    end
  end

  private

  def create_subscriptions_column!(table)
    case ActiveRecord::Base.connection.adapter_name
    when 'Mysql2'
      table.json :subscriptions
    when 'PostgreSQL'
      table.jsonb :subscriptions
    end
  end
end
