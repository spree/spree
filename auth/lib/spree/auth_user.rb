module Spree
  module AuthUser

    # Gives controllers the ability to learn the +auth_user+ as opposed to limiting them to just the standard
    # +current_user.+  The +auth_user+ method will return the user corresponding to the +guest_token+ if present,
    # otherwise it will return the +current_user.+  This allows us to check authorization against a guest user
    # without requiring that user to be signed in.  This means the guest can later sign up for
    # an acccount (or log in to an existing account.)
    def auth_user
      return current_user if current_user
      return nil if session[:guest_token].blank?
      User.find_by_persistence_token(session[:guest_token])
    end

  end
end
