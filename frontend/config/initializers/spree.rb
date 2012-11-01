require 'mail'

# Spree Configuration
SESSION_KEY = '_spree_session_id'

LIKE = ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' ? 'ILIKE' : 'LIKE'
