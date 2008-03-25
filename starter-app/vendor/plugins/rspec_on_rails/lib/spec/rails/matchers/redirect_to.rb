module Spec
  module Rails
    module Matchers

      class RedirectTo  #:nodoc:

        def initialize(request, expected)
          @expected = expected
          @request = request
        end

        def matches?(response)
          @redirected = response.redirect?
          @actual = response.redirect_url
          return false unless @redirected
          if @expected.instance_of? Hash
            return false unless @actual =~ %r{^\w+://#{@request.host}}
            return false unless actual_redirect_to_valid_route
            return actual_hash == expected_hash
          else
            return @actual == expected_url
          end
        end

        def actual_hash
          hash_from_url @actual
        end

        def expected_hash
          hash_from_url expected_url
        end

        def actual_redirect_to_valid_route
          actual_hash
        end

        def hash_from_url(url)
          query_hash(url).merge(path_hash(url)).with_indifferent_access
        end

        def path_hash(url)
          path = url.sub(%r{^\w+://#{@request.host}}, "").split("?", 2)[0]
          ActionController::Routing::Routes.recognize_path path
        end

        def query_hash(url)
          query = url.split("?", 2)[1] || ""
          QueryParameterParser.parse_query_parameters(query, @request)
        end

       def expected_url
          case @expected
            when Hash
              return ActionController::UrlRewriter.new(@request, {}).rewrite(@expected)
            when :back
              return @request.env['HTTP_REFERER']
            when %r{^\w+://.*}
              return @expected
            else
              return "http://#{@request.host}" + (@expected.split('')[0] == '/' ? '' : '/') + @expected
          end
        end

        def failure_message
          if @redirected
            return %Q{expected redirect to #{@expected.inspect}, got redirect to #{@actual.inspect}}
          else
            return %Q{expected redirect to #{@expected.inspect}, got no redirect}
          end
        end

        def negative_failure_message
            return %Q{expected not to be redirected to #{@expected.inspect}, but was} if @redirected
        end

        def description
          "redirect to #{@actual.inspect}"
        end

        class QueryParameterParser
          def self.parse_query_parameters(query, request)
            if defined?(CGIMethods)
              CGIMethods.parse_query_parameters(query)
            else
              request.class.parse_query_parameters(query)
            end
          end
        end
      end

      # :call-seq:
      #   response.should redirect_to(url)
      #   response.should redirect_to(:action => action_name)
      #   response.should redirect_to(:controller => controller_name, :action => action_name)
      #   response.should_not redirect_to(url)
      #   response.should_not redirect_to(:action => action_name)
      #   response.should_not redirect_to(:controller => controller_name, :action => action_name)
      #
      # Passes if the response is a redirect to the url, action or controller/action.
      # Useful in controller specs (integration or isolation mode).
      #
      # == Examples
      #
      #   response.should redirect_to("path/to/action")
      #   response.should redirect_to("http://test.host/path/to/action")
      #   response.should redirect_to(:action => 'list')
      def redirect_to(opts)
        RedirectTo.new(request, opts)
      end
    end

  end
end
