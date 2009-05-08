class GiveAllUsersUserRole < ActiveRecord::Migration
  require 'authlogic'
  def self.up
    user_role = Role.find_by_name("user")
    users = User.find(:all)
    users.each{|u|
      u.roles << user_role
      u.save
      }
  end

  def self.down
  end
end
