module Spree
  module TranslatableResourceSlug
    extend ActiveSupport::Concern

    class_methods do
      # Finds the record that most recently used the permalink, through
      # FriendlyId's history, within the current scope. A renamed record keeps
      # resolving under its old URLs; the caller compares the record's current
      # permalink and redirects.
      #
      # @param permalink [String]
      # @return [ActiveRecord::Base]
      # @raise [ActiveRecord::RecordNotFound] when no record in scope used it
      def find_from_permalink_history!(permalink)
        sluggable_ids = FriendlyId::Slug.where(sluggable_type: base_class.name, slug: permalink).
                        order(created_at: :desc).pluck(:sluggable_id)
        records_by_id = where(id: sluggable_ids).index_by(&:id)

        sluggable_ids.lazy.filter_map { |id| records_by_id[id] }.first ||
          raise(ActiveRecord::RecordNotFound.new("Couldn't find #{name} with permalink=#{permalink}", name))
      end
    end

    included do
      def localized_slugs_for_store(store)
        supported_locales = store.supported_locales_list

        supported_locales.each_with_object({}) do |locale, hash|
          hash[locale] = I18n.with_locale(locale) { slug }
        end
      end
    end
  end
end
