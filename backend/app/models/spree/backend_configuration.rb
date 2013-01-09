module Spree
  class BackendConfiguration < Preferences::Configuration
    preference :locale, :string, :default => 'en'
  end
end
