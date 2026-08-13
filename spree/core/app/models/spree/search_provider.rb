module Spree
  module SearchProvider
    # Meilisearch moved out of core into the spree_meilisearch gem at 6.0, taking
    # the document presenter with it. Applications configure the provider by
    # class name, so resolve the old constants to the new ones for one release
    # rather than failing at boot with a bare NameError.
    MOVED_TO_SPREE_MEILISEARCH = {
      Meilisearch: 'SpreeMeilisearch::SearchProvider',
      ProductPresenter: 'SpreeMeilisearch::ProductPresenter'
    }.freeze

    def self.const_missing(name)
      replacement = MOVED_TO_SPREE_MEILISEARCH[name]
      return super if replacement.nil?

      unless Object.const_defined?(replacement)
        raise NameError, "Spree::SearchProvider::#{name} moved to #{replacement} in Spree 6.0. " \
                         "Add `gem 'spree_meilisearch'` to your Gemfile."
      end

      Spree::Deprecation.warn(
        "Spree::SearchProvider::#{name} is deprecated and will be removed in Spree 6.1. " \
        "Use #{replacement} instead."
      ) if defined?(Spree::Deprecation)

      replacement.constantize
    end
  end
end
