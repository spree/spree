# Use singleton class Spree::Preferences::Store.instance to access
module Spree::Preferences

  class StoreInstance

    def initialize
      @cache = ActiveSupport::Cache::MemoryStore.new
      load_preferences
    end

    def set(key, value)
      @cache.write(key, value)
      persist(key, value)
    end

    def exist?(key)
      @cache.exist? key
    end

    def get(key, default_key=nil)
      @cache.read(key)
    end

    def delete(key)
      @cache.delete(key)
      destroy(key)
    end

    private

    def persist(cache_key, value)
      return unless Spree::Preference.table_exists?

      preference = Spree::Preference.find_or_initialize_by_key(cache_key)
      preference.value = value
      preference.save
    end

    def destroy(cache_key)
      preference = Spree::Preference.find_by_key(cache_key)
      preference.destroy if preference
    end

    def load_preferences
      return unless Spree::Preference.table_exists?

      Spree::Preference.all.each do |p|
         @cache.write(p.key, p.value)
      end
    end

  end

  class Store < StoreInstance
    include Singleton
  end

end
