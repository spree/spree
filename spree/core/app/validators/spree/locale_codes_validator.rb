module Spree
  # Rejects locale codes `Spree::Locales::ALL` does not list, in a single code
  # or a comma-separated list, naming the ones it refuses. Reads the stored
  # column, since a store answers `default_locale` from its default market,
  # and checks only an attribute that is changing, so a record saved before
  # the list was enforced can still be edited.
  #
  # @example
  #   validates_with Spree::LocaleCodesValidator, attributes: %i[default_locale supported_locales]
  class LocaleCodesValidator < ActiveModel::Validator
    def validate(record)
      Array(options[:attributes]).each do |attribute|
        next unless record.will_save_change_to_attribute?(attribute)

        unlisted = Spree::Locales.unlisted(record.read_attribute(attribute))
        next if unlisted.empty?

        record.errors.add(attribute, I18n.t('spree.locales_not_listed', codes: unlisted.join(', ')))
      end
    end
  end
end
