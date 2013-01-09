module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :locale, :string, :default => 'en'
  end
end
