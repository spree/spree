class AddPrivateMetadataToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    change_table :spree_newsletter_subscribers do |t|
      if t.respond_to? :jsonb
        t.jsonb :private_metadata, default: {}
      else
        t.json :private_metadata, default: {}
      end
    end
  end

  def down
    change_table :spree_newsletter_subscribers do |t|
      t.remove :private_metadata
    end
  end
end
