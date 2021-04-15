module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    has_and_belongs_to_many :stores

    validates :name, presence: true, uniqueness: true
  end
end
