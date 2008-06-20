# Add support for localization keys
require 'rails/core_ext'
require 'globalite/l10n'
require 'globalite/locale'
Symbol.send :include, SymbolExtension

module Globalite
  extend L10n
  def self.localize_rails
    ActiveRecord::Errors.relocalize
  end
end

# Localize Rails
require 'rails/localization.rb'
require 'rails/localized_action_view'
require 'rails/localized_active_record'

# added Boolean function to 'boolean' a string
module Kernel
  def Boolean(string)
    return true if string == true || string =~ /^true$/i
    return false if string == false || string.nil? || string =~ /^false$/i
    raise ArgumentError.new("invalid value for Boolean: \"#{string}\"")
  end
end

Globalite.load_localization!
