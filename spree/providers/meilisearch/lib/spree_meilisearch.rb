require 'meilisearch'
require 'pagy/toolbox/paginators/meilisearch'
require 'spree_core'
require 'spree_meilisearch/engine'

module SpreeMeilisearch
  # Meilisearch server the store's index lives on. Credentials are read from the
  # environment rather than a Spree::Integration record because the index is
  # infrastructure — one server serves every store in the installation, and the
  # rake reindex task has to reach it outside a request.
  def self.client
    ::Meilisearch::Client.new(
      ENV.fetch('MEILISEARCH_URL', 'http://localhost:7700'),
      ENV['MEILISEARCH_API_KEY']
    )
  end
end
