class RenameSpreeGiftCardsStateToStatus < ActiveRecord::Migration[8.1]
  def change
    rename_column :spree_gift_cards, :state, :status
  end
end
