module Spree
  # The credential a client sends. Its resource owner is a real user, so a
  # call carries that person's own permissions resolved fresh on every
  # request — narrowing a role or deleting the user takes effect immediately,
  # without touching the token. This is what an API key cannot do: a key is a
  # standing grant with nobody behind it.
  class OauthAccessToken < Spree.base_class
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken

    self.table_name = 'spree_oauth_access_tokens'

    belongs_to :application,
               class_name: 'Spree::OauthApplication',
               optional: true
  end
end
