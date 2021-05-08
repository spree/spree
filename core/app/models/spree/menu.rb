module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    belongs_to :store

    before_validation :paremeterize_unique_code
    after_create :set_root

    validates :name, :store, presence: true
    validates :unique_code, uniqueness: { scope: :store }

    scope :by_store, ->(store) { where store: store }

    has_one :root, -> { where(parent_id: nil) }, class_name: 'Spree::MenuItem', dependent: :destroy

    def self.by_unique_code(menu_code)
      find_by(unique_code: menu_code)
    end

    private

    def paremeterize_unique_code
      self.unique_code = unique_code.parameterize
    end

    def set_root
      self.root ||= MenuItem.create!(menu_id: id, name: name, item_type: 'Container')
    end
  end
end
