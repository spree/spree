class CreateSpreeWebhooksEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_webhooks_events do |t|
      t.integer "execution_time"
      t.string "response_code", index: true
      t.string "request_errors"
      t.bigint "subscriber_id", null: false
      t.boolean "success", index: true
      t.string "url", null: false
      t.index ["subscriber_id"], name: "index_spree_webhooks_events_on_subscriber_id"
    end
  end
end
