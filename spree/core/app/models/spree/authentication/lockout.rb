module Spree
  module Authentication
    # The login lockout contract, for every place that checks a secret the
    # account owner knows. A check that skips it becomes an unthrottled way to
    # guess the password: a locked account is refused, a miss counts towards
    # the lockout and a hit clears the count.
    #
    # Duck-typed, so a custom user class that implements none of the lockout
    # hooks is checked without them.
    module Lockout
      module_function

      # @param user [Object] the account whose secret is being checked
      # @yieldreturn [Boolean] whether the secret matched
      # @return [Symbol] +:locked+, +:valid+ or +:invalid+
      def check(user)
        return :locked if user.respond_to?(:locked?) && user.locked?

        if yield
          # Require the full contract before touching the counter — a custom
          # user class may implement one hook but not the other.
          if user.respond_to?(:failed_attempts) && user.respond_to?(:reset_failed_attempts!) &&
             user.failed_attempts.to_i.positive?
            user.reset_failed_attempts!
          end
          :valid
        else
          user.record_failed_attempt! if user.respond_to?(:record_failed_attempt!)
          :invalid
        end
      end
    end
  end
end
