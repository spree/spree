module Spree
  module Store::MultiStoreClassOverrides
    def current(url = nil)
      if url.present?
        Spree.current_store_finder.new(url: url).execute
      else
        Spree::Current.store
      end
    end

    def available_locales
      Spree::Store.all.map(&:supported_locales_list).flatten.uniq
    end
  end
end
