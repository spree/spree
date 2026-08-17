module Spree
  class Policy < Spree.base_class
    has_prefix_id :pol

    extend FriendlyId
    include Spree::TranslatableResource
    include Spree::SanitizableRichText

    UNIQUENESS_SCOPE = %i[owner_id owner_type].freeze

    #
    # FriendlyId
    #
    friendly_id :slug_candidates, use: %i[slugged scoped history], scope: UNIQUENESS_SCOPE

    #
    # Associations
    #
    belongs_to :owner, polymorphic: true, touch: true # can be a store or a seller or organization

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name body].freeze
    RICH_TEXT_TRANSLATABLE_FIELDS = %i[body].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    #
    # Rich text
    #
    has_spree_rich_text :body

    self::Translation.class_eval do
      include Spree::SanitizableRichText

      sanitizes_rich_text :body
    end

    #
    # Validations
    #
    validates :slug, presence: true, uniqueness: { scope: UNIQUENESS_SCOPE }
    validates :name, presence: true
    validates :owner, presence: true

    #
    # Scopes
    #
    scope :with_body, -> { where.not(body: [nil, '']) }
    scope :without_body, -> { where(body: [nil, '']) }
    scope :with_matching_name, ->(name_to_match) do
      value = name_to_match.to_s.strip.downcase

      if Spree.use_translations?
        i18n { name.lower.eq(value) }
      else
        where(arel_table[:name].lower.eq(value))
      end
    end

    #
    #  Ransack
    #
    self.whitelisted_ransackable_attributes = %w[name owner_type owner_id]

    before_destroy :really_destroy_slugs!

    # For policies, store.policies returns all policies owned by the store
    # We don't want to filter out other policies in requests that use `for_store` when they have a different owner type
    def self.for_store(store)
      store.policies.or(where.not(owner_type: 'Spree::Store'))
    end

    def with_body?
      body.present?
    end

    def really_destroy_slugs!
      slugs.with_deleted.each(&:really_destroy!)
    end
  end
end
