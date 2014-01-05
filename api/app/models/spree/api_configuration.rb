module Spree
  class ApiConfiguration < Preferences::Configuration
    preference :requires_authentication, :boolean, :default => false
  end
end
