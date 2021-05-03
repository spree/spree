module Spree
  class Navigation < Spree::Base
    self.table_name = 'spree_menus_stores'

    belongs_to :menu, class_name: 'Spree::Menu'
    belongs_to :store, class_name: 'Spree::Store'
  end
end
