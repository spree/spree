Spree::Store.new do |s|
  s.name              = 'Spree Demo Site'
  s.url               = 'demo.spreecommerce.com'
  s.mail_from_address = 'spree@example.com'
end.save!
