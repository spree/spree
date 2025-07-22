class AddAcceptMarketingAndSignupForAnAccountToSpreeOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_orders, :accept_marketing, :boolean, default: false, if_not_exists: true
    add_column :spree_orders, :signup_for_an_account, :boolean, default: false, if_not_exists: true
  end
end
