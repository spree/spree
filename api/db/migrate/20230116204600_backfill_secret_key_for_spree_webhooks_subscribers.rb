class BackfillSecretKeyForSpreeWebhooksSubscribers < ActiveRecord::Migration[7.0]
  def change
    Spree::Webhooks::Subscriber.where(secret_key: nil).find_each(&:regenerate_secret_key)
  end
end
