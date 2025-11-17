module Spree
  class Post < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Linkable
    include Spree::Metafields
    extend FriendlyId

    friendly_id :slug_candidates, use: %i[slugged scoped history], scope: %i[store_id deleted?]
    acts_as_paranoid
    acts_as_taggable_on :tags
    acts_as_taggable_tenant :store_id

    if defined?(PgSearch)
      include PgSearch::Model
      pg_search_scope :search_by_title, against: :title
    else
      scope :search_by_title, ->(query) { where('title LIKE ?', "%#{query}%") }
    end

    #
    # Ransack filtering
    #
    self.whitelisted_ransackable_attributes = %w[author_id post_category_id published_at]
    self.whitelisted_ransackable_associations = %w[author post_category]
    self.whitelisted_ransackable_scopes = %w[search_by_title]

    #
    # Attachments
    #
    has_one_attached :image, service: Spree.public_storage_service_name

    #
    # Rich Text
    #
    has_rich_text :content
    has_rich_text :excerpt

    #
    # Associations
    #
    belongs_to :author, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :posts
    belongs_to :post_category, class_name: 'Spree::PostCategory', optional: true, touch: true, inverse_of: :posts
    alias category post_category

    #
    # Validations
    #
    validates :title, :store, presence: true
    validates :slug, presence: true, uniqueness: { scope: :store_id, conditions: -> { where(deleted_at: nil) } }
    validates :meta_title, length: { maximum: 160 }, allow_blank: true
    validates :meta_description, length: { maximum: 320 }, allow_blank: true
    validates :image, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Scopes
    #
    scope :published, -> { where(published_at: [..Time.current]) }
    scope :by_newest, -> { order(created_at: :desc) }

    delegate :name, to: :author, prefix: true, allow_nil: true
    delegate :title, to: :post_category, prefix: true, allow_nil: true

    def should_generate_new_friendly_id?
      slug.blank? || (persisted? && title_changed?)
    end

    def slug_candidates
      [
        :title,
        [:title, :id]
      ]
    end

    def published?
      published_at.present?
    end

    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:post_path)

      Spree::Core::Engine.routes.url_helpers.post_path(self)
    end

    def publish(date = nil)
      update(published_at: date || Time.current)
    end

    def unpublish
      update(published_at: nil)
    end

    def description
      excerpt.to_plain_text.presence || content.to_plain_text
    end

    def shortened_description
      desc = excerpt.to_plain_text.presence || content.to_plain_text
      desc.length > 320 ? "#{desc[0...320]}..." : desc
    end

    def self.to_tom_select_json
      pluck(:id, :title).map do |id, title|
        {
          id: id,
          name: title
        }
      end.as_json
    end
  end
end
