module Spree
  class Menu < Spree::Base
    include SingleStoreResource

    has_many :menu_items, dependent: :destroy
    belongs_to :store, touch: true

    before_validation :parameterize_location

    after_initialize :load_locations

    after_create :set_root
    after_save :update_root_name
    after_touch :touch_store

    validates :name, :store, :locale, presence: true
    validates :location, uniqueness: { scope: [:store, :locale] }

    has_one :root, -> { where(parent_id: nil) }, class_name: 'Spree::MenuItem', dependent: :destroy

    default_scope { order(created_at: :asc) }

    scope :by_locale, ->(locale) { where(locale: locale) }

    self.whitelisted_ransackable_attributes = %w[name location locale store_id]

    def load_locations
      self.class.refresh_for_locations
    end

    def self.refresh_for_locations
      MenuLocation.all.each do |location|
        define_singleton_method("for_#{location.parameterized_name}") do |locale|
          menu = find_by(location: location.parameterized_name, locale: locale.to_s)

          menu.root if menu.present?
        end
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
