module Spree
  if ActiveRecord::Base.connected?
    LIKE = ActiveRecord::Base.connection.adapter_name == 'PostgreSQL' ? 'ILIKE' : 'LIKE'
  end
end
