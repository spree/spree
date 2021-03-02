default_store = Spree::Store.default

if default_store.persisted?
  default_store.update!(default_country_id: Spree::Config[:default_country_id])
else
  Spree::Store.new do |s|
    s.name                         = 'Spree Demo Site'
    s.code                         = 'spree'
    s.url                          = Rails.application.routes.default_url_options[:host] || 'demo.spreecommerce.org'
    s.mail_from_address            = 'no-reply@example.com'
    s.customer_support_email       = 'support@example.com'
    s.default_currency             = 'USD'
    s.default_country_id           = Spree::Config[:default_country_id]
    s.default_locale               = I18n.locale
    s.seo_title                    = 'Spree Commerce Demo Shop'
    s.meta_description             = 'This is the new Spree UX DEMO | OVERVIEW: http://bit.ly/new-spree-ux | DOCS: http://bit.ly/spree-ux-customization-docs | CONTACT: https://spreecommerce.org/contact/'
    s.facebook                     = 'spreecommerce'
    s.twitter                      = 'spreecommerce'
    s.instagram                    = 'spreecommerce'
  end.save!
end
