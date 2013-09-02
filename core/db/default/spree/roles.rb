Spree::Role.where(:name => "admin").first_or_create
Spree::Role.where(:name => "user").first_or_create
