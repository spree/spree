module Spree
  module AuthUser

    # Gives controllers the ability to learn the +auth_user+ as opposed to limiting them to just the standard
    # +current_user.+  The +auth_user+ method will return the user corresponding to the +guest_token+ if present,
    # otherwise it will return the +current_user.+  This allows us to check authorization against a guest user
    # without requiring that user to be signed in.  This means the guest can later sign up for
    # an acccount (or log in to an existing account.)
    def auth_user
      return current_user unless session[:guest_token]
      User.find_by_persistence_token(session[:guest_token])
    end

    # Overrides the default method used by Cancan so that we can use the guest_token in addition to current_user.
    def current_ability
      @current_ability ||= ::Ability.new(auth_user)
    end

  end
end
