require 'i18n'
require 'active_support/core_ext/array/extract_options'
require 'spree/i18n/base'
require 'action_view'

module Spree
  extend ::ActionView::Helpers::TranslationHelper
  extend ::ActionView::Helpers::TagHelper

  class << self
    # Add spree namespace and delegate to Rails TranslationHelper for some nice
    # extra functionality. e.g return reasonable strings for missing translations
    def translate(*args)
      options = args.extract_options!
      options[:scope] = [*options[:scope]].unshift(:spree).uniq
      args << options
      super(*args)
    end

    alias t translate
  end
end
