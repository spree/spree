# frozen_string_literal: true

# This migration comes from spree (originally 20251214000002)
class CreateSpreeWebhookDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_webhook_deliveries do |t|
      t.belongs_to :webhook_endpoint, null: false, foreign_key: false, index: true
      t.string :event_name, null: false, index: true
      if t.respond_to?(:jsonb)
        t.jsonb :payload, null: false
      else
        t.json :payload, null: false
      end
      t.integer :response_code, index: true
      t.text :response_body
      t.string :error_type
      t.integer :execution_time
      t.text :request_errors
      t.boolean :success, index: true
      t.datetime :delivered_at, index: true
      t.timestamps
    end
  end
end
