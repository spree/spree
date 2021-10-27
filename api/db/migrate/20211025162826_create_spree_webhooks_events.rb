class CreateSpreeWebhooksEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_webhooks_events do |t|
      t.integer "execution_time"
      t.string "response_code", index: true
      t.string "request_errors"
      t.belongs_to "subscriber"
      t.boolean "success", index: true
      t.string "url", null: false
    end
  end
end
