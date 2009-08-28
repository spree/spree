# Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

class CreateAdminUser
  
  # note: this is not really a true 404 - it actually just tells rails to continue metal chain
  CONTINUE_CHAIN = [404, {"Content-Type" => "text/html"}, ["Not Found"]]
  
  def self.call(env)
    session = env["rack.session"]
    return CONTINUE_CHAIN if env["PATH_INFO"] =~ /^\/users/ or session['admin-user'] or not User.table_exists?
    session['admin-user'] = User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])
    return CONTINUE_CHAIN if session['admin-user'] 
    # redirect to user creation
    [302, {'Location'=> '/users/new' }, []]
  ensure
    # Release the connections back to the pool.
    ActiveRecord::Base.clear_active_connections!
  end
  
end
