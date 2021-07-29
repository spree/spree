class MigrateSpreeI18nGlobalizeConfig < ActiveRecord::Migration[5.2]
  def up
    locales = []

    if defined?(SpreeI18n) && defined?(SpreeI18n::Config)
      locales = (locales << SpreeI18n::Config[:available_locales]).flatten.uniq.compact
    end

    if defined?(SpreeGlobalize) && defined?(SpreeGlobalize::Config)
      locales = (locales << SpreeGlobalize::Config[:supported_locales]).flatten.uniq.compact
    end

    default_store = Spree::Store.default
    if default_store.supported_locales.blank? || default_store.supported_locales == default_store.default_locale
      locales = (locales << default_store.default_locale).uniq.compact.join(',')
      default_store.update(supported_locales: locales)
    end
  end

  def down
  end
end
