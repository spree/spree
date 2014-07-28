# Possibly already created by a migration.
unless Spree::Store.where(code: 'doorstep').exists?
  Spree::Store.new do |s|
    s.code              = 'doorstep'
    s.name              = 'Doorstep demo site'
    s.url               = 'demo.doorstep.com'
    s.mail_from_address = 'doorstep@example.com'
  end.save!
end