class CreateStoreFromPreferences < ActiveRecord::Migration
  def change
    preference_store = Spree::Preferences::Store.instance

    # we set defaults for the things we now require
    Spree::Store.new do |s|
      s.name              = preference_store.get 'spree/app_configuration/site_name' do
        'Spree Demo Site'
      end
      s.url               = preference_store.get 'spree/app_configuration/site_url' do
        'demo.spreecommerce.com'
      end
      s.mail_from_address = preference_store.get 'spree/app_configuration/mails_from' do
        'spree@example.com'
      end

      s.meta_description = preference_store.get('spree/app_configuration/default_meta_description') {}
      s.meta_keywords    = preference_store.get('spree/app_configuration/default_meta_keywords') {}
      s.seo_title        = preference_store.get('spree/app_configuration/default_seo_title') {}
      s.default_currency = preference_store.get('spree/app_configuration/currency') {}

    end.save!
  end
end
