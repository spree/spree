module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    has_many :navigations, inverse_of: :menu
    has_many :stores, through: :navigations

    before_validation :paremeterize_unique_code
    after_create :set_root

    validate :uniqueness_of_code_within_stores
    validates :name, presence: true

    scope :by_store, ->(store) { joins(:stores).where('store_id = ?', store) }
    scope :by_unique_code, ->(menu_code) { where unique_code: menu_code }

    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::MenuItem', dependent: :destroy

    private

    def paremeterize_unique_code
      self.unique_code = unique_code.parameterize
    end

    def set_root
      self.root ||= MenuItem.create!(menu_id: id, name: name, item_type: 'Container', code: "#{name}-root")
    end

    def uniqueness_of_code_within_stores
      menus = []

      store_ids.map do |store_id|
        Menu.by_store(store_id).
          by_unique_code(unique_code).
          each { |match| menus << match.name unless id == match.id }
      end

      unless menus.empty?
        errors.add(:unique_code,
                   Spree.t('admin.navigation.unique_code_store_error',
                           code: unique_code,
                           menus: menus[0]))
      end
    end
  end
end
