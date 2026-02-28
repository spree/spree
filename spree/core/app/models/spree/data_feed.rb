module Spree
  class DataFeed < Spree.base_class
    has_prefix_id :df

    belongs_to :store, class_name: 'Spree::Store', foreign_key: 'store_id'

    scope :for_store, ->(store) { where(store: store) }
    scope :active, -> { where(active: true) }

    before_validation :generate_slug

    with_options presence: true do
      validates :store
      validates :name, uniqueness: true
      validates :slug, uniqueness: { scope: :store_id }
    end

    def formatted_url
      "#{store.formatted_url}/api/v3/store/feeds/#{slug}.xml"
    end

    private

    def generate_slug
      new_slug = slug.blank? ? SecureRandom.uuid : slug.parameterize
      write_attribute(:slug, new_slug)
    end

    class << self
      def label
        raise NotImplementedError
      end

      def provider_name
        raise NotImplementedError
      end

      def presenter_class
        raise NotImplementedError
      end

      def available_types
        Spree.data_feed_types
      end
    end
  end
end
