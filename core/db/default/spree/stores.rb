# Possibly already created by a migration.
unless Spree::Store.where(code: 'spree').exists?
  Spree::Store.new do |s|
    s.code              = 'spree'
    s.name              = 'Spree Demo Site'
    s.url               = Rails.application.routes.default_url_options[:host] || 'example.com'
    s.mail_from_address = 'spree@example.com'
    s.default_currency  = 'USD'
  end.save!
end
