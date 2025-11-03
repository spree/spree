module Spree
  class Policy < Spree.base_class
    extend FriendlyId
    include Spree::TranslatableResource
    include Spree::Linkable

    UNIQUENESS_SCOPE = %i[owner_id owner_type].freeze

    #
    # FriendlyId
    #
    friendly_id :slug_candidates, use: %i[slugged scoped history], scope: UNIQUENESS_SCOPE

    #
    # Associations
    #
    belongs_to :owner, polymorphic: true, touch: true # can be a store or a vendor or organization

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name body].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    #
    # ActionText
    #
    translates :body, backend: :action_text

    #
    # Validations
    #
    validates :slug, presence: true, uniqueness: { scope: UNIQUENESS_SCOPE }
    validates :name, presence: true
    validates :owner, presence: true

    #
    # Scopes
    #
    scope :with_body,    -> { joins(:rich_text_body).distinct }
    scope :without_body, -> { where.missing(:rich_text_body) }

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

    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:policy_path)

      Spree::Core::Engine.routes.url_helpers.policy_path(self)
    end

    def with_body?
      body.present?
    end

    def really_destroy_slugs!
      slugs.with_deleted.each(&:really_destroy!)
    end
  end
end
