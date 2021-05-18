module Spree
  class Menu < Spree::Base
    MENU_LOCATIONS = ['Header', 'Footer']
    MENU_LOCATIONS_PARAMETERIZED = []

    MENU_LOCATIONS.each do |location|
      parameterize_location = location.parameterize(separator: '_')
      MENU_LOCATIONS_PARAMETERIZED << parameterize_location
    end

    has_many :menu_items, dependent: :destroy
    belongs_to :store, touch: true

    before_validation :paremeterize_location
    after_create :set_root
    after_save :update_root_name
    after_touch :touch_store

    validates :name, :store, :locale, presence: true
    validates :location, uniqueness: { scope: [:store, :locale] }
    validates :location, inclusion: { in: MENU_LOCATIONS_PARAMETERIZED }

    has_one :root, -> { where(parent_id: nil) }, class_name: 'Spree::MenuItem', dependent: :destroy

    scope :by_store, ->(store) { where(store: store) }
    scope :by_locale, ->(locale) { where(locale: locale) }

    self.whitelisted_ransackable_attributes = %w[name location locale store_id]

    MENU_LOCATIONS_PARAMETERIZED.each do |name|
      define_singleton_method("for_#{name}") do |locale|
        menu = find_by(location: name, locale: locale.to_s) || find_by(location: name)
        if menu.present?
          menu.root
        end
      end
    end

    private

    def paremeterize_location
      return unless location.present?

      self.location = location.parameterize(separator: '_')
    end

    def set_root
      self.root ||= MenuItem.create!(menu_id: id, name: name, item_type: 'Container')
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
