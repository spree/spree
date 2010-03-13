# Always create the admin user, in the case when we want to test the
# middleware explicity remove the admin user.
#
Before do
  User.first(:include => :roles, :conditions => ["roles.name = 'admin'"]) || Factory(:admin_user)
end
