# Make redirects for SEO needs
module Spree
  module Core
    module Middleware
      class SeoAssist
        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)
          params = request.params

          taxon_id = params['taxon']

          #redirect requests using taxon id's to their permalinks
          if !taxon_id.blank? && !taxon_id.is_a?(Hash) && taxon = Taxon.find(taxon_id)
            params.delete('taxon')

            return build_response(params, "#{request.script_name}t/#{taxon.permalink}" )
          elsif env["PATH_INFO"] =~ /^\/(t|products)(\/\S+)?\/$/
            #ensures no trailing / for taxon and product urls

            return build_response(params, env["PATH_INFO"][0...-1])
          end

          @app.call(env)
        end

        private

        def build_response(params, location)
          query = build_query(params)
          location += '?' + query unless query.blank?
          [301, { 'Location'=> location }, []]
        end

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
    end
  end
end
