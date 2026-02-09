# frozen_string_literal: true

# This migration comes from spree (originally 20251214000001)
class CreateSpreeWebhookEndpoints < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_webhook_endpoints do |t|
      t.belongs_to :store, null: false, foreign_key: false, index: true
      t.string :url, null: false
      t.boolean :active, null: false, default: true, index: true
      if t.respond_to? :jsonb
        t.jsonb :subscriptions, null: false
      else
        t.json :subscriptions, null: false
      end
      t.string :secret_key, null: false
      t.datetime :deleted_at, index: true
      t.timestamps
    end
  end
end
