class AuthlogicChanges < ActiveRecord::Migration
  def self.up
      change_table :users do |t| 
          t.string    :persistence_token  
          t.string    :single_access_token 
          t.string    :perishable_token    
          t.integer   :login_count,         :null => false, :default => 0 
          t.integer   :failed_login_count,  :null => false, :default => 0 
          t.datetime  :last_request_at                                    
          t.datetime  :current_login_at                                   
          t.datetime  :last_login_at                                      
          t.string    :current_login_ip                                   
          t.string    :last_login_ip                                      
      end     
      change_column :users, :crypted_password, :string, :limit => 128,
                    :null => false, :default => ""
      change_column :users, :salt, :string, :limit => 128,
                    :null => false, :default => ""                    
      User.reset_column_information 
  end

  def self.down
  end
end
