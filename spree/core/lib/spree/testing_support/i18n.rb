# Deprecated: Spree's specs now catch missing keys through Rails'
# config.i18n.raise_on_missing_translations. Removed in Spree 6.1.
Spree::Deprecation.warn("spree/testing_support/i18n is deprecated and does nothing; set config.i18n.raise_on_missing_translations = true in your test environment instead. It will be removed in Spree 6.1.") if defined?(Spree::Deprecation)
