module Spree
  class Menu < Spree::Base
    MENU_LOCATIONS = ['Header', 'Footer']
    MENU_LOCATIONS_PARAMETERIZED = []
    MENU_LOCATIONS_FOR_SELECT = []

    MENU_LOCATIONS.each do |location|
      parameterize_location = location.parameterize(separator: '_')
      MENU_LOCATIONS_PARAMETERIZED << parameterize_location
      MENU_LOCATIONS_FOR_SELECT << [location, parameterize_location]
    end

    has_many :menu_items, dependent: :destroy
    belongs_to :store

    before_validation :paremeterize_location
    after_create :set_root

    validates :name, :store, :locale, presence: true
    validates :location, uniqueness: { scope: [:store, :locale] }
    validates :location, inclusion: { in: MENU_LOCATIONS_PARAMETERIZED }

    has_one :root, -> { where(parent_id: nil) }, class_name: 'Spree::MenuItem', dependent: :destroy

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
      self.location = location.parameterize(separator: '_')
    end

    def set_root
      self.root ||= MenuItem.create!(menu_id: id, name: name, item_type: 'Container')
    end
  end
end
