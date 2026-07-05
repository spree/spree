module Spree
  # CanCanCan ability used for API-key-authenticated admin requests.
  # Grants full access — authorization happens at the scope-check layer
  # (Spree::Api::V3::ScopedAuthorization), not at the per-record CanCanCan
  # layer. This exists so that `accessible_by(current_ability, :show)` in
  # admin controllers returns the unrestricted scope (it would otherwise
  # require a real Spree::Ability with role lookups, which doesn't apply
  # to API key principals).
  class ApiKeyAbility
    include CanCan::Ability

    def initialize(_options = {})
      can :manage, :all
    end
  end
end
