module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    has_and_belongs_to_many :stores

    after_create :set_root
    after_save :set_root_menu_item_name

    validates :name, presence: true
    validates :unique_code, presence: true, uniqueness: true

    scope :by_store, ->(store) { joins(:stores).where('store_id = ?', store) }
    scope :by_unique_code, ->(menu_code) { where unique_code: menu_code }

    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::MenuItem', dependent: :destroy

    private

    def set_root
      code_name = name.parameterize

      self.root ||= MenuItem.create!(menu_id: id, name: name, item_type: 'Container', code: "#{code_name}-root")
    end

    def set_root_menu_item_name
      root.update(name: name)
    end
  end
end
