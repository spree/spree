class MakeExistingCreditCardsDefault < ActiveRecord::Migration
  def up
    # set the newest credit card for every user to be the default; SQL technique from
    # http://stackoverflow.com/questions/121387/fetch-the-row-which-has-the-max-value-for-a-column
    Spree::CreditCard.where.not(user_id: nil).joins("LEFT OUTER JOIN spree_credit_cards cc2 ON cc2.user_id = spree_credit_cards.user_id AND spree_credit_cards.created_at < cc2.created_at").where("cc2.user_id IS NULL").update_all(default: true)
  end
  def down
    # do nothing
  end
end
