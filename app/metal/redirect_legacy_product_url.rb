class RedirectLegacyProductUrl

  def self.call(env)                
    if env["PATH_INFO"] =~ %r{/t/.+/p/(.+)}      
      return [301, {'Location'=> "/products/#{$1}" }, []]  
    end
    [404, {"Content-Type" => "text/html"}, "Not Found"]
  end
  
end