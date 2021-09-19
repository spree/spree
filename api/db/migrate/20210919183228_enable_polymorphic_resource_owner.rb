class EnablePolymorphicResourceOwner < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_oauth_access_tokens, :resource_owner_type, :string
    add_column :spree_oauth_access_grants, :resource_owner_type, :string
    change_column_null :spree_oauth_access_grants, :resource_owner_type, false

    add_index :spree_oauth_access_tokens,
              [:resource_owner_id, :resource_owner_type],
              name: 'polymorphic_owner_oauth_access_tokens'

    add_index :spree_oauth_access_grants,
              [:resource_owner_id, :resource_owner_type],
              name: 'polymorphic_owner_oauth_access_grants'

    Spree::OauthAccessToken.reset_column_information
    Spree::OauthAccessToken.update_all(resource_owner_type: Spree.user_class)

    Spree::OauthAccessGrant.reset_column_information
    Spree::OauthAccessGrant.update_all(resource_owner_type: Spree.user_class)
  end
end
