# This file exists solely to test whether or not there are missing translations
# within the code that Spree's test suite covers.
#
# If there is a translation referenced which has no corresponding key within the
# .yml file, then there will be a message output at the end of the suite showing
# that.
#
# If there is a translation within the locale file which *isn't* used in the
# test, this will also be shown at the end of the suite run.
module Spree
  class << self
    attr_accessor :used_translations, :missing_translation_messages,
                  :unused_translations, :unused_translation_messages
    alias_method :normal_t, :t
  end

  def self.t(*args)
    original_args = args.dup
    options = args.extract_options!
    self.used_translations ||= []
    [*args.first].each do |translation_key|
      key = ([*options[:scope]] << translation_key).join('.')
      self.used_translations << key
    end
    normal_t(*original_args)
  end

  def self.check_missing_translations
    self.missing_translation_messages = []
    self.used_translations ||= []
    used_translations.map { |a| a.split('.') }.each do |translation_keys|
      root = translations
      processed_keys = []
      translation_keys.each do |key|
        begin
          root = root.fetch(key.to_sym)
          processed_keys << key.to_sym
        rescue KeyError
          error = "#{(processed_keys << key).join('.')} (#{I18n.locale})"
          unless Spree.missing_translation_messages.include?(error)
            Spree.missing_translation_messages << error
          end
        end
      end
    end
  end

  def self.check_unused_translations
    self.used_translations ||= []
    self.unused_translation_messages = []
    self.unused_translations = []
    self.load_translations(translations)
    translation_diff = unused_translations - used_translations
    translation_diff.each do |translation|
      Spree.unused_translation_messages << "#{translation} (#{I18n.locale})"
    end
  end

  private

  def self.load_translations(hash, root=[])
    hash.each do |k,v|
      if v.is_a?(Hash)
        load_translations(v, root.dup << k)
      else
        key = (root + [k]).join('.')
        self.unused_translations << key
      end
    end
  end

  def self.translations
    @translations ||= I18n.backend.send(:translations)[I18n.locale][:spree]
  end
end

RSpec.configure do |config|
  # Need to check here again because this is used in i18n_spec too.
  if ENV['CHECK_TRANSLATIONS']
    config.after :suite do
      Spree.check_missing_translations
      if Spree.missing_translation_messages.any?
        puts "\nThere are missing translations within Spree:"
        puts Spree.missing_translation_messages.sort
        exit(1)
      end

      Spree.check_unused_translations
      if false && Spree.unused_translation_messages.any?
        puts "\nThere are unused translations within Spree:"
        puts Spree.unused_translation_messages.sort
        exit(1)
      end
    end
  end
end

