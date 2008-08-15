module Localization
  module UserPreferences
    def self.included(base)
      base.class_eval do
        preference :locale, :string, :default => 'en-US'
      end
    end
  end
end
