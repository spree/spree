require 'i18n'
require 'active_support/core_ext/array/extract_options'

module Spree
  def self.t(*args)
    options = args.extract_options!
    options[:scope] = [*options[:scope]].unshift(:spree)
    args << options
    I18n.t(*args)
  end
end

