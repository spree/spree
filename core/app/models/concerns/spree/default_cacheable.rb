module Spree
  module DefaultCacheable
    extend ActiveSupport::Concern
    included do
      before_save :ensure_default
      before_save :reload_cache
    end

    module ClassMethods
      def default_cache_key
        "#{Rails.application.class.parent_name.underscore}_default_#{name.demodulize.underscore}"
      end

      def default_query
        column_names.include?('default') ?
          where(default: true).first : column_names.include?('is_default') ?
          where(is_default: true).first : first
      end

      def default
        Rails.cache.fetch(default_cache_key) do
          default_query
        end
      end
    end

    private

    def ensure_default
      if respond_to?(:default)
        if default
          self.class.where(default: true).where.not(id: id).update_all(default: false, updated_at: Time.current)
        else
          self.default = true if self.class.where(default: true).count.zero?
        end
      elsif respond_to?(:is_default)
        if is_default
          self.class.where(is_default: true).where.not(id: id).update_all(is_default: false, updated_at: Time.current)
        else
          self.is_default = true if self.class.where(is_default: true).count.zero?
        end
      end
    end

    def reload_cache
      Rails.cache.delete(self.class.default_cache_key)
    end
  end
end

