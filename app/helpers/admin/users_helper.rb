module Admin::UsersHelper        
  def list_roles(user)
    user.roles.collect {|role| role.name}.join ", "    
  end
end
