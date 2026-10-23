module Spree
  # Switches a staff account off without deleting it. Deleting a staff member
  # clears them from every record that names them as its actor, so the history
  # of who approved, refunded or created what is lost; deactivating keeps the
  # account and refuses every way back in.
  #
  # Enforcement lives in the API: a deactivated account cannot sign in by any
  # strategy, accept an invitation, finish a password reset or refresh a
  # session, and its access tokens stop working on the next request. Including
  # this concern opts a model in; the checks are duck-typed, so a custom admin
  # user class without it is never refused.
  #
  # Secret API keys are left alone: they belong to the store, not to the person
  # who created them, and revoking them would break the store's integrations.
  module AccountDeactivation
    # @return [Boolean]
    def deactivated?
      deactivated_at.present?
    end

    # Deactivates the account and ends every session it holds: refresh tokens
    # are deleted, and OAuth tokens and grants issued to apps on its behalf are
    # revoked. Access tokens already issued are refused from the next request.
    #
    # Skips validations: switching an account off must not fail because some
    # unrelated attribute no longer passes today's rules.
    #
    # @return [void]
    def deactivate!
      return if deactivated?

      now = Time.current
      transaction do
        update_columns(deactivated_at: now, updated_at: now)
        Spree::RefreshToken.revoke_all_for(self)
        oauth_owner = { resource_owner_type: self.class.polymorphic_name, resource_owner_id: id, revoked_at: nil }
        Spree::OauthAccessToken.where(oauth_owner).update_all(revoked_at: now)
        Spree::OauthAccessGrant.where(oauth_owner).update_all(revoked_at: now)
      end
    end

    # Lets the account sign in again. Sessions ended by deactivation stay
    # ended; the person signs in afresh.
    #
    # @return [void]
    def reactivate!
      return unless deactivated?

      update_columns(deactivated_at: nil, updated_at: Time.current)
    end
  end
end
