# Use singleton class Spree::Preferences::Store.instance to access
#
# StoreInstance has a persistence flag that is on by default,
# but we disable database persistence in testing to speed up tests
#
module Spree::Preferences

  class StoreInstance
    attr_accessor :persistence

    def initialize
      @cache = Rails.cache
      @persistence = true
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
      return unless should_persist?

      preference = Spree::Preference.find_or_initialize_by_key(cache_key)
      preference.value = value
      preference.save
    end

    def destroy(cache_key)
      return unless should_persist?

      preference = Spree::Preference.find_by_key(cache_key)
      preference.destroy if preference
    end

    def load_preferences
      return unless should_persist?

      Spree::Preference.all.each do |p|
         @cache.write(p.key, p.value)
      end
    end

    def should_persist?
      @persistence and Spree::Preference.table_exists?
    end

  end

  class Store < StoreInstance
    include Singleton
  end

end
