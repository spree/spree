# note: we're not returning 404 in the usuaul sense - it actually just tells rails to continue metal chain
class CreateAdminUser
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] =~ /^\/users|stylesheets/ or @admin_defined or not User.table_exists?
      @app.call(env)
    else
      if User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])
        @app.call(env)
      else
        [302, {'Location'=> 'users/sign_up' }, []]
      end
    end
  ensure
    # Release the connections back to the pool.
    ActiveRecord::Base.clear_active_connections!
  end

end
