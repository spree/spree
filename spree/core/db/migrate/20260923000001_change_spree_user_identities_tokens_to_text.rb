class ChangeSpreeUserIdentitiesTokensToText < ActiveRecord::Migration[8.1]
  def up
    change_column :spree_user_identities, :access_token, :text
    change_column :spree_user_identities, :refresh_token, :text
  end

  def down
    change_column :spree_user_identities, :access_token, :string
    change_column :spree_user_identities, :refresh_token, :string
  end
end
