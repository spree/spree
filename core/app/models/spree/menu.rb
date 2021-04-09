module Spree
  class Menu < Spree::Base
    has_many :menu_items, dependent: :destroy
    validates :name, presence: true
  end
end
