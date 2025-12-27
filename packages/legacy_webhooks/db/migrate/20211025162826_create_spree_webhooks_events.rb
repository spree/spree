class CreateSpreeWebhooksEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_webhooks_events do |t|
      t.integer "execution_time"
      t.string "name", null: false
      t.string "request_errors"
      t.string "response_code", index: true
      t.belongs_to "subscriber", null: false, index: true
      t.boolean "success", index: true
      t.string "url", null: false
      t.timestamps
    end
  end
end
