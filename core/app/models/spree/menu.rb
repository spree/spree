module Spree
  class Menu < Spree::Base
    include SingleStoreResource
    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

    MENU_LOCATIONS = ['Header', 'Footer']
    MENU_LOCATIONS_PARAMETERIZED = []

    MENU_LOCATIONS.each do |location|
      parameterize_location = location.parameterize(separator: '_')
      MENU_LOCATIONS_PARAMETERIZED << parameterize_location
    end

    has_many :menu_items, dependent: :destroy, class_name: 'Spree::MenuItem'
    belongs_to :store, touch: true, class_name: 'Spree::Store'

    before_validation :parameterize_location
    after_create :set_root
    after_save :update_root_name
    after_touch :touch_store

    validates :name, :store, :locale, presence: true
    validates :location, uniqueness: { scope: [:store, :locale] }
    validates :location, inclusion: { in: MENU_LOCATIONS_PARAMETERIZED }

    has_one :root, -> { where(parent_id: nil) }, class_name: 'Spree::MenuItem', dependent: :destroy

    default_scope { order(created_at: :asc) }

    scope :by_locale, ->(locale) { where(locale: locale) }

    self.whitelisted_ransackable_attributes = %w[name location locale store_id]

    MENU_LOCATIONS_PARAMETERIZED.each do |location_name|
      define_singleton_method("for_#{location_name}") do |locale|
        menu = find_by(location: location_name, locale: locale.to_s)

        menu.root if menu.present?
      end
    end

    private

    def parameterize_location
      return unless location.present?

      self.location = location.parameterize(separator: '_')
    end

    def set_root
      self.root ||= menu_items.create!(name: name, item_type: 'Container')
    end

    def update_root_name
      return unless saved_change_to_name?

      root.update(name: name)
    end

    def touch_store
      store.touch
    end
  end
end
