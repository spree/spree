module UsersHelper       
  def password_style(user)
    show_openid ? "display:none" : ""
  end         
  def openid_style(user) 
    show_openid ? "": "display:none"
  end
  
  private 
  def show_openid
    Spree::Config[:allow_openid] and @user.openid_identifier
  end
end