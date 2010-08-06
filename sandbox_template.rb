File.open("Gemfile", 'w') { |f| }
gem 'rails', '>=3.0.0.rc'
# IMPORTANT: __FILE__ refer to (eval), not to sandbox_template.rb !!!
gem "spree", :path => ".."

gem 'sqlite3-ruby'
gem 'ruby-debug' if RUBY_VERSION.to_f < 1.9

# Use unicorn as the web server
# gem 'unicorn'

gem "spree_sample", :path => "../sample", :require => ['spree_sample','spree_sample/engine']

application "require 'spree_core/all'"
remove_file "public/index.html"

append_file "public/robots.txt", <<-ROBOTS
User-agent: *
Disallow: /checkouts
Disallow: /orders
Disallow: /countries
Disallow: /line_items
Disallow: /password_resets
Disallow: /states
Disallow: /user_sessions
Disallow: /users
ROBOTS

permissions = <<-PERMISSIONS
# Add to this this file to define the role(s) needed to process an action.
##Format
# FirstControllerName:                             # name of Controller
#  permission_N:                                   # must =~ /permission\d+/
#    roles : [role_name1, role_name2, role_name3]  # all roles for the controller must be listed here
#    options :
#      option_name : options_value                 # these options apply to all allowed roles
#      option_name : options_value
#  permission_N+1:
#    role : [role_name1]                           # a roll_name from permission_N
#    options :
#      option_name : options_value                 # options specific to that roll_name
#      option_name : options_value
#      option_name : options_value
#      option_name : options_value
# SecondControllerName:
#  ...
##Example Usage:
# UserController:
#  permission1:
#    roles : [admin, user]
#'Admin::BaseController':       # require admin role for all actions on this controller
#  permission1:                 # and all controllers that inherit from it that are not
#    role : admin               # given explicit permissions
#'Admin::UsersController':
#  permission1:
#    role : [admin, shipper]    # require either of these roles for all actions
#  permission2:
#    role : admin
#    options :
#      except : [index, show]   # now shipper can only use #index and #show
#      unless : "current_user.authorized_for_listing?(params[:id])"
#
##Valid options
#
#  * :only - Only require the role for the given action(s)
#  * :for  - same as :only
#  * :except - Require the role for everything but the given action(s)
#  * :for_all_except  - same as :except
#  * :if - takes a string to eval in the context of the controller.
#          If it evaluates to true, the role is required.
#  * :unless - The inverse of :if
#

# By default, admin role is required for all controllers extending Admin::BaseController (unless otherwise specified here)
'Admin::BaseController':
  permission1:
    roles : [admin]
# Users can only see their own accounts
'UsersController':
  permission1:
    roles : [admin]
    options :
      except : [new, create]
      unless : "current_user and current_user.id == object.id"
'OrdersController':
  permission1:
    # Users can only see their own orders
    roles : [admin]
    options :
      except : [new, create, cvv]
      unless : can_access?  #orders_controller may grant access based on presence of token, etc.
'CheckoutsController':
  permission1:
    # Users can only see their own orders
    roles : [admin]
    options :
      unless : can_access?  #checkouts_controller may grant access based on presence of token, etc.
PERMISSIONS

create_file "config/spree_permissions.yml", permissions

append_file "db/seeds.rb", <<-SEEDS
Rake::Task["db:load_dir"].invoke( "default" )
puts "Default data has been loaded"
SEEDS

run "mkdir -p db/migrate"
run "mkdir -p db/default"
run "mkdir -p db/sample/assets"
