class CreateSpreeNewsletterSubscribers < ActiveRecord::Migration[8.0]
  def change
    create_table :spree_newsletter_subscribers do |t|
      t.string :email, index: { unique: true }, null: false
      t.bigint :user_id, index: true
      t.datetime :verified_at, index: true
      t.string :verification_token, index: { unique: true }

      t.timestamps
    end
  end
end
