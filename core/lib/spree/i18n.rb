require 'i18n'
require 'active_support/core_ext/array/extract_options'

module Spree
  extend ActionView::Helpers::TranslationHelper
  extend ActionView::Helpers::TagHelper

  class << self
    # Add spree namespace and delegate to Rails TranslationHelper for some nice
    # extra functionality. e.g return reasonable strings for missing translations
    def translate(*args)
      options = args.extract_options!
      options[:scope] = [*options[:scope]].unshift(:spree)
      args << options
      super(*args)
    end

    alias_method :t, :translate
  end
end
