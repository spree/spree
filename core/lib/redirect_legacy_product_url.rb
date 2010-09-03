class RedirectLegacyProductUrl
  def initialize(app)
    @app = app
  end
  
  def call(env)                
    if env["PATH_INFO"] =~ %r{/t/.+/p/(.+)}      
      return [301, {'Location'=> "/products/#{$1}" }, []]  
    end
    @app.call(env)
  end
  
end
