module Spree
  class DataFeed < Base
    belongs_to :store, class_name: 'Spree::Store', foreign_key: 'store_id'

    scope :for_store, ->(store) { where(store: store) }

    before_validation :generate_slug

    with_options presence: true do
      validates :store
      validates :name, uniqueness: true
      validates :provider
      validates :slug, uniqueness: { scope: :store_id }
    end

    def formatted_url
      "#{store.formatted_url}/api/v2/data_feeds/#{provider}/#{slug}.rss"
    end

    private

    def generate_slug
      new_slug = slug.blank? ? SecureRandom.uuid : slug.parameterize
      write_attribute(:slug, new_slug)
    end
  end
end
