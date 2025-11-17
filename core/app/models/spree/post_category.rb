module Spree
  class PostCategory < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metafields
    extend FriendlyId

    friendly_id :slug_candidates, use: %i[slugged scoped history], scope: %i[store_id]

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :post_categories
    has_many :posts, class_name: 'Spree::Post', dependent: :nullify, inverse_of: :post_category

    #
    # Validations
    #
    validates :title, :store, presence: true
    validates :slug, presence: true, uniqueness: { scope: :store_id }

    #
    # ActionText
    #
    has_rich_text :description

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[title slug]

    def should_generate_new_friendly_id?
      slug.blank? || title_changed?
    end

    def slug_candidates
      [
        :title,
        [:title, :id]
      ]
    end
  end
end
