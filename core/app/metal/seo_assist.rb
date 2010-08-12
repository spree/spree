# Make redirects for SEO needs
class SeoAssist
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    params = request.params
    taxon_id = params['taxon']
    if !taxon_id.blank? && !taxon_id.is_a?(Hash) && @taxon = Taxon.find(taxon_id)
      params.delete('taxon')
      query = build_query(params)
      permalink = @taxon.permalink[0...-1] #ensures no trailing / for taxon urls
      return [301, { 'Location'=> "/t/#{permalink}?#{query}" }, []]
    elsif env["PATH_INFO"] =~ /^\/(t|products)(\/\S+)?\/$/
      #ensures no trailing / for taxon and product urls
      query = build_query(params)
      new_location = env["PATH_INFO"][0...-1]
      new_location += '?' + query unless query.blank?
      return [301, { 'Location'=> new_location }, []]
    end
    @app.call(env)
  end

  private

  def build_query(params)
    params.map { |k, v|
      if v.class == Array
        build_query(v.map { |x| ["#{k}[]", x] })
      else
        k + "=" + Rack::Utils.escape(v)
      end
    }.join("&")
  end

end
