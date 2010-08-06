require 'spree_core'
require 'spree_api'
require 'spree_dashboard'
require 'spree_payment_gateway'
require 'spree_promotions'
require 'spree_sample'

begin
  # contains site specific logic for overriding spree stuff
  require 'spree_site'
rescue Exception
  # no big deal - we can generate one using 'rails g spree:site'
end