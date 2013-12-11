module Spree
  class ApiConfiguration < Preferences::Configuration
    # Make sure the api requires authentication by default to prevent unwanted access
    preference :requires_authentication, :boolean, :default => true
  end
end
