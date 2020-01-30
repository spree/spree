# Possibly already created by a migration.
unless Spree::Store.default.persisted?
  Spree::Store.new do |s|
    s.name              = 'Spree Demo Site'
    s.code              = 'spree'
    s.url               = Rails.application.routes.default_url_options[:host] || 'demo.spreecommerce.org'
    s.mail_from_address = 'spree@example.com'
    s.default_currency  = 'USD'
    s.seo_title         = 'Spree Commerce Demo Shop'
    s.meta_description  = 'Spree Commerce is an open source Ecommerce framework decision makers want, developers enjoy.'
    s.facebook          = 'spreecommerce'
    s.twitter           = 'spreecommerce'
    s.instagram         = 'spreecommerce'
  end.save!
end
