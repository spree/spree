class AddStoreIdToSpreeNewsletterSubscribers < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_newsletter_subscribers, :store
  end
end
