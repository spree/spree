require 'spree/core/preferences/runtime_configuration'

module Spree
  module Core
    class RuntimeConfiguration < Preferences::RuntimeConfiguration
      preference :always_use_translations, :boolean, default: false
    end
  end
end
