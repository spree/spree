class CreateStoreFromPreferences < ActiveRecord::Migration[4.2]
  def change
    Spree::Store.class_eval do
      # workaround for spree_i18n and Store translations
      def self.translated?(name)
        false
      end
      # workaround for paranoia gem's validation for Store created in this file; it could be any of the existing columns
      self.paranoia_column = :id
    end

    preference_store = Spree::Preferences::Store.instance
    if store = Spree::Store.with_deleted.where(default: true).first
      store.meta_description = preference_store.get('spree/app_configuration/default_meta_description') {}
      store.meta_keywords    = preference_store.get('spree/app_configuration/default_meta_keywords') {}
      store.seo_title        = preference_store.get('spree/app_configuration/default_seo_title') {}
      store.default_currency = preference_store.get('spree/app_configuration/currency') { 'USD' }
      store.save!
    else
      # we set defaults for the things we now require
      Spree::Store.new do |s|
        s.name              = preference_store.get 'spree/app_configuration/site_name' do
          'Spree Demo Site'
        end
        s.url               = preference_store.get 'spree/app_configuration/site_url' do
          'demo.spreecommerce.org'
        end
        s.mail_from_address = preference_store.get 'spree/app_configuration/mails_from' do
          'spree@example.com'
        end

        s.meta_description = preference_store.get('spree/app_configuration/default_meta_description') do
          'This is the new Spree UX DEMO | OVERVIEW: http://bit.ly/new-spree-ux | DOCS: http://bit.ly/spree-ux-customization-docs | CONTACT: https://spreecommerce.org/contact/'
        end
        s.meta_keywords    = preference_store.get('spree/app_configuration/default_meta_keywords') {}
        s.seo_title        = preference_store.get('spree/app_configuration/default_seo_title') do
          'Spree Commerce Demo Shop'
        end
        s.default_currency = preference_store.get('spree/app_configuration/currency') { 'USD' }
        s.code             = 'spree'
      end.save!
    end
  end
end
