# Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

# note: we're not returning 404 in the usuaul sense - it actually just tells rails to continue metal chain
class CreateAdminUser  
  
  def self.call(env)                
    if env["PATH_INFO"] =~ /^\/users|stylesheets/ or @admin_defined or not User.table_exists?
      @status = [404, {"Content-Type" => "text/html"}, "Not Found"]
    else
      @admin_defined = User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])
      @status = [404, {"Content-Type" => "text/html"}, "Not Found"] if @admin_defined
    end
    # redirect to user creation screen
    return @status || [302, {'Location'=> '/users/new' }, []]
  ensure
    # Release the connections back to the pool.
    ActiveRecord::Base.clear_active_connections!
  end
  
end
