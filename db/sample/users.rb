# HACK - need to add all sample users to the 'user' role (can't do this in sample fixtures because user role is seed data)
user_role = Role.find_by_name "user"
if user_role
  User.all.each { |u| u.roles << user_role unless u.has_role?("user") } 
end

# see last line where we create an admin if there is none, asking for email and password

def prompt_for_admin_password
  password = ask('Password [spree]: ', String) do |q|
    q.echo = false
    q.validate = /^(|.{5,40})$/
    q.responses[:not_valid] = "Invalid password. Must be at least 5 characters long."
    q.whitespace = :strip
  end
  password = "spree" if password.blank?
  password
end
 
def prompt_for_admin_email
  email = ask('Email [spree@example.com]: ', String) do |q|
    q.echo = true
    q.whitespace = :strip
  end
  email = "spree@example.com" if email.blank?
  email
end  

def create_admin_user
  if ENV['AUTO_ACCEPT']
    password =  "spree"
    email =  "spree@example.com"          
  else
    require 'highline/import' 
    puts "Create the admin user (press enter for defaults)."
    #name = prompt_for_admin_name unless name
    email = prompt_for_admin_email 
    password = prompt_for_admin_password 
  end
  attributes = {
    :password => password,
    :password_confirmation => password,
    :email => email,
    :login => email
  }

  load 'user.rb'
  
  if User.find_by_login(email)
    say "\nWARNING: There is already a user with the email: #{email}, so no account changes were made.  If you wish to create an additional admin user, please run rake db:admin:create again with a different email.\n\n"
  else
    admin = User.create(attributes)
    # create an admin role and and assign the admin user to that role
    role = Role.find_or_create_by_name "admin"
    admin.roles << role
    admin.save
  end      
end

create_admin_user unless User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])     
