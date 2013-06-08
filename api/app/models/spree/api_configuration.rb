module Spree
  class ApiConfiguration < Preferences::Configuration
    preference :requires_authentication, :boolean, :default => false
    preference :cache_timeout, :integer, :default => 5
  end
end
