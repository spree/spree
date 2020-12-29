module Spree
  module TestingSupport
    module ControllerRequests
      extend ActiveSupport::Concern

      included do
        routes { Spree::Core::Engine.routes }
      end

      def spree_get(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_get is deprecated and will be removed in Spree 4.1.
          Please use get, params: {}
        DEPRECATION
        process_spree_action(action, parameters, session, flash, 'GET')
      end

      # Executes a request simulating POST HTTP method and set/volley the response
      def spree_post(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_post is deprecated and will be removed in Spree 4.1.
          Please use post, params: {}
        DEPRECATION
        process_spree_action(action, parameters, session, flash, 'POST')
      end

      # Executes a request simulating PUT HTTP method and set/volley the response
      def spree_put(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_put is deprecated and will be removed in Spree 4.1.
          Please use put, params: {}
        DEPRECATION
        process_spree_action(action, parameters, session, flash, 'PUT')
      end

      # # Executes a request simulating PATCH HTTP method and set/volley the response
      def spree_patch(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_patch is deprecated and will be removed in Spree 4.1.
          Please use patch, params: {}
        DEPRECATION
        process_spree_action(action, parameters, session, flash, 'PATCH')
      end

      # Executes a request simulating DELETE HTTP method and set/volley the response
      def spree_delete(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_delete is deprecated and will be removed in Spree 4.1.
          Please use delete, params: {}
        DEPRECATION
        process_spree_action(action, parameters, session, flash, 'DELETE')
      end

      def spree_xhr_get(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_xhr_get is deprecated and will be removed in Spree 4.1.
        DEPRECATION
        process_spree_xhr_action(action, parameters, session, flash, :get)
      end

      def spree_xhr_post(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_xhr_post is deprecated and will be removed in Spree 4.1.
        DEPRECATION
        process_spree_xhr_action(action, parameters, session, flash, :post)
      end

      def spree_xhr_put(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_xhr_put is deprecated and will be removed in Spree 4.1.
        DEPRECATION
        process_spree_xhr_action(action, parameters, session, flash, :put)
      end

      def spree_xhr_patch(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_xhr_patch is deprecated and will be removed in Spree 4.1.
        DEPRECATION
        process_spree_xhr_action(action, parameters, session, flash, :patch)
      end

      def spree_xhr_delete(action, parameters = nil, session = nil, flash = nil)
        ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
          ControllerRequests#spree_xhr_delete is deprecated and will be removed in Spree 4.1.
        DEPRECATION
        process_spree_xhr_action(action, parameters, session, flash, :delete)
      end

      private

      def process_spree_action(action, parameters = nil, session = nil, flash = nil, method = 'GET')
        parameters ||= {}
        process(action, method: method, params: parameters, session: session, flash: flash)
      end

      def process_spree_xhr_action(action, parameters = nil, session = nil, flash = nil, method = :get)
        parameters ||= {}
        parameters.reverse_merge!(format: :json)
        process(action, method: method, params: parameters, session: session, flash: flash, xhr: true)
      end
    end
  end
end
