module Spree
  class PageLink < Spree.base_class
    #
    # Magic methods
    #
    acts_as_list scope: :parent

    #
    # Associations
    #
    belongs_to :parent, polymorphic: true, touch: true, counter_cache: true # Block or Section
    belongs_to :linkable, polymorphic: true, optional: true # Page, Product, etc.
    has_one :theme, through: :parent

    #
    # Validations
    #
    validates :label, :parent, presence: true
    validates :url, presence: true, unless: :linkable

    #
    # Callbacks
    #
    after_destroy :notify_parent
    before_validation :set_label, on: [:create, :update]

    def linkable_url
      @linkable_url ||= linkable&.page_builder_url || formatted_url
    end

    def formatted_url
      return if url.blank?
      return url if url.start_with?("mailto:")

      @formatted_url ||= url.match(/http:\/\/|https:\/\//) ? url : "http://#{url}"
    end

    private

    def notify_parent
      return unless parent.present?
      return unless parent.respond_to?(:link_destroyed)

      parent.link_destroyed(self)
    end

    def set_label
      return if label.present? && new_record?
      return unless linkable_id_changed?

      if linkable.respond_to?(:title)
        self.label = linkable.title
      elsif linkable.respond_to?(:display_name)
        self.label = linkable.display_name
      elsif linkable.respond_to?(:name)
        self.label = linkable.name
      end
    end
  end
end
