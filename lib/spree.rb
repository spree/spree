require 'spree_core/all'
require 'spree_sample'

begin
  # contains site specific logic for overriding spree stuff
  require 'spree_site'
rescue Exception
  # no big deal - we can generate one using 'rails g spree:site'
end