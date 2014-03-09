class CreateStoreFromPreferences < ActiveRecord::Migration
  def change
    preference_store = Spree::Preferences::Store.instance

    # we set defaults for the things we now require
    Spree::Store.new do |s|
      s.name              = preference_store.get('spree/app_configuration/site_name') || 'Spree Demo Site'
      s.url               = preference_store.get('spree/app_configuration/site_url') || 'demo.spreecommerce.com'
      s.mail_from_address = preference_store.get('spree/app_configuration/mails_from') || 'spree@example.com'

      s.meta_description = preference_store.get 'spree/app_configuration/default_meta_description'
      s.meta_keywords    = preference_store.get 'spree/app_configuration/default_meta_keywords'
      s.seo_title        = preference_store.get 'spree/app_configuration/default_seo_title'
      s.default_currency = preference_store.get 'spree/app_configuration/currency'
    end.save!
  end
end
