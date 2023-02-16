class BackfillSecretKeyForSpreeWebhooksSubscribers < ActiveRecord::Migration[6.1]
  def change
    Spree::Webhooks::Subscriber.where(secret_key: nil).find_each(&:regenerate_secret_key)
  end
end
