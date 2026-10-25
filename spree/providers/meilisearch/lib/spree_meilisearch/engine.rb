require 'rails/engine'

module SpreeMeilisearch
  class Engine < Rails::Engine
    engine_name 'spree_meilisearch'

    config.after_initialize do
      # The document shape is Meilisearch's own — one document per locale and
      # currency, plus per-grouping membership documents carrying the position a
      # manual sort orders by. Installing the gem therefore also supplies the
      # presenter that builds it, unless the application named its own subclass.
      unless Spree::Dependencies.overridden?(:search_product_presenter)
        Spree::Dependencies.search_product_presenter = 'SpreeMeilisearch::ProductPresenter'
      end
    end
  end
end
