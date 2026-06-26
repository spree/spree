# Configures the effective supported locales for a store in specs, accounting
# for markets being the source of truth when present. Setting only the
# `supported_locales` column is silently ignored once a store has markets
# (see Spree::Stores::Markets#supported_locales_list), which makes
# locale-dependent specs order-flaky.
module TranslationLocalesHelper
  # @param store [Spree::Store]
  # @param locales [Array<String>] e.g. %w[en de fr]; the first is the default
  def configure_supported_locales(store, locales)
    default = locales.first
    csv = locales.join(',')

    # update_column (not update!) bypasses ActiveModel dirty-checking. The
    # shared @default_store is created in before(:all) (the outer transaction);
    # each example's savepoint rolls back its writes, but the in-memory object
    # keeps the new value — so a later update!(supported_locales: same_value)
    # is a no-op (no dirty attr) and the DB stays at its rolled-back state.
    # update_column always issues the UPDATE.
    store.update_column(:default_locale, default)
    store.update_column(:supported_locales, csv)

    store.markets.reload.each do |market|
      market.update_column(:supported_locales, csv)
      market.update_column(:default_locale, default)
      market.remove_instance_variable(:@supported_locales_list) if market.instance_variable_defined?(:@supported_locales_list)
    end

    clear_locale_memoization(store)
    store
  end

  def clear_locale_memoization(store)
    %i[@supported_locales_list @has_markets].each do |ivar|
      store.remove_instance_variable(ivar) if store.instance_variable_defined?(ivar)
    end
  end
end

RSpec.configure do |config|
  config.include TranslationLocalesHelper
end
