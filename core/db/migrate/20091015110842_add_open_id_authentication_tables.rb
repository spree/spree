class AddOpenIdAuthenticationTables < ActiveRecord::Migration
  def change
    create_table :open_id_authentication_associations, :force => true do |t|
      t.integer  :issued, :lifetime
      t.string   :handle, :assoc_type
      t.binary   :server_url, :secret
    end

    create_table :open_id_authentication_nonces, :force => true do |t|
      t.integer  :timestamp,  :null => false
      t.string   :server_url, :null => true
      t.string   :salt,       :null => false
    end
  end
end
