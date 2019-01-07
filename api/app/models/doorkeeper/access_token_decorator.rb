Doorkeeper::AccessToken.class_eval do
  self.table_name = 'spree_oauth_access_tokens'
end
