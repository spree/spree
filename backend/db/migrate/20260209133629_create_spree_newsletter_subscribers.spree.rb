# This migration comes from spree (originally 20250826093602)
class CreateSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_newsletter_subscribers do |t|
      t.string :email, index: { unique: true }, null: false
      t.references :user, index: true
      t.datetime :verified_at, index: true
      t.string :verification_token, index: { unique: true }

      t.timestamps
    end
  end
end
