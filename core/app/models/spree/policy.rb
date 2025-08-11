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
    # ActionText
    #
    translates :body, backend: :action_text

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

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
  end
end
