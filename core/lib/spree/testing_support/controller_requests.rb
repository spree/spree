# Use this module to easily test Spree actions within Spree components
# or inside your application to test routes for the mounted Spree engine.
#
# Inside your spec_helper.rb, include this module inside the RSpec.configure
# block by doing this:
#
#   require 'spree/testing_support/controller_requests'
#   RSpec.configure do |c|
#     c.include Spree::TestingSupport::ControllerRequests, :type => :controller
#   end
#
# Then, in your controller tests, you can access spree routes like this:
#
#   require 'spec_helper'
#
#   describe Spree::ProductsController do
#     it "can see all the products" do
#       spree_get :index
#     end
#   end
#
# Use spree_get, spree_post, spree_put or spree_delete to make requests
# to the Spree engine, and use regular get, post, put or delete to make
# requests to your application.
#
module Spree
  module TestingSupport
    module ControllerRequests
      def spree_get(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "GET")
      end

      # Executes a request simulating POST HTTP method and set/volley the response
      def spree_post(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "POST")
      end

      # Executes a request simulating PUT HTTP method and set/volley the response
      def spree_put(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "PUT")
      end

      # Executes a request simulating DELETE HTTP method and set/volley the response
      def spree_delete(action, parameters = nil, session = nil, flash = nil)
        process_spree_action(action, parameters, session, flash, "DELETE")
      end

      def spree_xhr_get(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :get)
      end

      def spree_xhr_post(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :post)
      end

      def spree_xhr_put(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :put)
      end

      def spree_xhr_delete(action, parameters = nil, session = nil, flash = nil)
        process_spree_xhr_action(action, parameters, session, flash, :delete)
      end

      private

      def process_spree_action(action, parameters = nil, session = nil, flash = nil, method = "GET")
        parameters ||= {}
        process(action, method, parameters.merge!(:use_route => :spree), session, flash)
      end

      def process_spree_xhr_action(action, parameters = nil, session = nil, flash = nil, method = :get)
        parameters ||= {}
        parameters.reverse_merge!(:format => :json)
        parameters.merge!(:use_route => :spree)
        xml_http_request(method, action, parameters, session, flash)
      end
    end
  end
end


