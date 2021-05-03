module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    has_many :navigations, inverse_of: :menu
    has_many :stores, through: :navigations

    before_validation :paremeterize_unique_code
    after_create :set_root

    validate :uniqueness_of_code_within_scope_of_stores

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

    def uniqueness_of_code_within_scope_of_stores
      existing_menu = []

      store_ids.map do |s|
        Spree::Menu.by_store(s).by_unique_code(unique_code).each { |m| existing_menu << m.name unless id == m.id }
      end

      unless existing_menu.empty?
        errors.add(:unique_code, Spree.t('admin.navigation.scope_unique_name_store_id_error', code: unique_code, menus: existing_menu[0]))
      end
    end
  end
end
