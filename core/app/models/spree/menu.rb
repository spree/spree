module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    has_and_belongs_to_many :stores

    before_validation :paremeterize_unique_code
    after_create :set_root
    after_save :set_root_menu_item_name

    validates :name, presence: true
    validates :unique_code, presence: true, uniqueness: true

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

    def set_root_menu_item_name
      root.update(name: name)
    end
  end
end
