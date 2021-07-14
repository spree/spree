Spree::MenuLocation.where(
  name: 'Header'
).first_or_create!

Spree::MenuLocation.where(
  name: 'Footer'
).first_or_create!
