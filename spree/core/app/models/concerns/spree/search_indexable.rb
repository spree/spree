module Spree
  module SearchIndexable
    extend ActiveSupport::Concern

    included do
      after_commit :enqueue_search_index, on: [:create, :update]
      after_commit :enqueue_search_removal, on: :destroy
    end

    # Index this record synchronously (inline, no job).
    # Useful for bulk imports, rake tasks, or when you need immediate indexing.
    def add_to_search_index
      return unless search_indexing_enabled?

      store_ids_for_indexing.each do |store_id|
        store = Spree::Store.find_by(id: store_id)
        next unless store

        provider = Spree.search_provider.constantize.new(store)
        provider.index(self)
      end
    end

    # Returns the hash that would be sent to the search provider for indexing.
    # Useful for debugging and previewing what gets indexed.
    #
    #   product.search_presentation         # uses Spree::Current.store
    #   product.search_presentation(store)  # explicit store
    #   => { id: 1, name: "Shirt", price_USD: 19.99, ... }
    def search_presentation(store = nil)
      store ||= Spree::Current.store
      Spree::Dependencies.search_product_presenter_class.new(self, store).call
    end

    # Remove this record from search index synchronously (inline, no job).
    def remove_from_search_index
      return unless search_indexing_enabled?

      store_ids_for_indexing.each do |store_id|
        store = Spree::Store.find_by(id: store_id)
        next unless store

        provider = Spree.search_provider.constantize.new(store)
        provider.remove(self)
      end
    end

    def enqueue_search_index
      return unless search_indexing_enabled?

      store_ids_for_indexing.each do |store_id|
        Spree::SearchProvider::IndexJob.perform_later(self.class.name, id.to_s, store_id.to_s)
      end
    end

    def enqueue_search_removal
      return unless search_indexing_enabled?

      pid = prefixed_id
      store_ids_for_indexing.each do |store_id|
        Spree::SearchProvider::RemoveJob.perform_later(pid, store_id.to_s)
      end
    end

    def search_indexing_enabled?
      Spree.search_provider.constantize.indexing_required?
    rescue NameError
      false
    end

    def store_ids_for_indexing
      if respond_to?(:store_ids)
        store_ids
      elsif respond_to?(:store_id)
        [store_id].compact
      else
        Spree::Store.pluck(:id)
      end
    end
  end
end
