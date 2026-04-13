class AddMetadataToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def up
    change_table :spree_newsletter_subscribers do |t|
      if t.respond_to? :jsonb
        t.jsonb :metadata
      else
        t.json :metadata
      end
    end
  end

  def down
    change_table :spree_newsletter_subscribers do |t|
      t.remove :metadata
    end
  end
end
