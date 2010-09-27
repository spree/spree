# Overrides the default current_ability method used by Cancan so that we can use the guest_token in addition to current_user.
# We were having problems layering the custom logic on top of ActionController::Base in certain situations but overriding
# this file within spree_auth seems to do the trick. Documentation has been stripped (see cancan for the original docs.)
# Only the current_ability method has been changed.

module CanCan

  module ControllerAdditions
    module ClassMethods

      def load_and_authorize_resource(*args)
        ControllerResource.add_before_filter(self, :load_and_authorize_resource, *args)
      end

      def load_resource(*args)
        ControllerResource.add_before_filter(self, :load_resource, *args)
      end

      def authorize_resource(*args)
        ControllerResource.add_before_filter(self, :authorize_resource, *args)
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.helper_method :can?, :cannot?
    end

    def authorize!(action, subject, *args)
      message = nil
      if args.last.kind_of?(Hash) && args.last.has_key?(:message)
        message = args.pop[:message]
      end
      raise AccessDenied.new(message, action, subject) if cannot?(action, subject, *args)
    end

    def unauthorized!(message = nil)
      raise ImplementationRemoved, "The unauthorized! method has been removed from CanCan, use authorize! instead."
    end

    def current_ability
      # HACKED to use Spree's auth_user instead of current_user
      @current_ability ||= ::Ability.new(auth_user)
    end

    def can?(*args)
      current_ability.can?(*args)
    end

    def cannot?(*args)
      current_ability.cannot?(*args)
    end
  end
end

if defined? ActionController
  ActionController::Base.class_eval do
    include CanCan::ControllerAdditions
  end
end
