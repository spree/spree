module Spree
  class BackendConfiguration < Preferences::Configuration
    preference :locale, :string, :default => 'en_US'
  end
end
