# This migration comes from spree (originally 20250915093930)
class AddMetadataToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    change_table :spree_newsletter_subscribers do |t|
      if t.respond_to? :jsonb
        t.jsonb :public_metadata
        t.jsonb :private_metadata
      else
        t.json :public_metadata
        t.json :private_metadata
      end
    end
  end

  def down
    change_table :spree_newsletter_subscribers do |t|
      t.remove :public_metadata
      t.remove :private_metadata
    end
  end
end
