require 'spree_core'
require 'spree_api'
require 'spree_backend'
require 'spree_frontend'
require 'spree_sample'

begin
  require 'protected_attributes'
  puts "*" * 75
  puts "[FATAL] Spree does not work with the protected_attributes gem installed!"
  puts "You MUST remove this gem from your Gemfile. It is incompatible with Spree."
  puts "*" * 75
  exit
rescue LoadError
end
