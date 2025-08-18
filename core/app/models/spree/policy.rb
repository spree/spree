module Spree
  class Policy < Spree.base_class
    extend FriendlyId
    include Spree::SingleStoreResource
    include Spree::TranslatableResource

    acts_as_list scope: %i[store_id]

    #
    # FriendlyId
    #
    friendly_id :slug_candidates, use: %i[slugged scoped history], scope: %i[store_id]

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', touch: true

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
    validates :slug, presence: true, uniqueness: { scope: %i[store_id] }
    validates :name, :body, presence: true
    validates :show_in_checkout_footer, inclusion: { in: [true, false] }

    #
    # Scopes
    #
    scope :show_in_checkout_footer, -> { where(show_in_checkout_footer: true) }

    #
    #  Ransack
    #
    self.whitelisted_ransackable_attributes = %w[name show_in_checkout_footer]

    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:policy_path)

      Spree::Core::Engine.routes.url_helpers.policy_path(self)
    end
  end
end
