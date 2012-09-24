# Use singleton class Spree::Preferences::Store.instance to access
#
# StoreInstance has a persistence flag that is on by default,
# but we disable database persistence in testing to speed up tests
#

require 'singleton'

module Spree::Preferences

  class StoreInstance
    attr_accessor :persistence

    def initialize
      @cache = Rails.cache
      @persistence = true
      load_preferences
    end

    def set(key, value, type)
      @cache.write(key, value)
      persist(key, value, type)
    end

    def exist?(key)
      @cache.exist?(key) || Spree::Preference.where(:key => key).exists?
    end

    def get(key)
      # look first in our cache
      val = @cache.read(key)

      # return the retrieved value, if it's in the cache
      return val unless val.nil?

      return nil unless should_persist?      

      # if it's not in the cache, maybe it's in the database, but 
      # has been cleared from the cache

      # does it exist in the database?
      preference = Spree::Preference.find_by_key key

      if preference.present?

        # it does exist, so let's put it back into the cache
        @cache.write(preference.key, preference.value)

        # and return the value
        return preference.value
      else
        # it never existed and our initial cache miss was correct
        return nil
      end
    end

    def delete(key)
      @cache.delete(key)
      destroy(key)
    end

    private

    def persist(cache_key, value, type)
      return unless should_persist?

      preference = Spree::Preference.where(:key => cache_key).first_or_initialize
      preference.value = value
      preference.value_type = type
      preference.save
    end

    def destroy(cache_key)
      return unless should_persist?

      preference = Spree::Preference.find_by_key(cache_key)
      preference.destroy if preference
    end

    def load_preferences
      return unless should_persist?

      Spree::Preference.valid.each do |p|
        Spree::Preference.convert_old_value_types(p) # see comment
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
