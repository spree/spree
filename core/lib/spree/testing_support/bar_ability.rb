# Fake ability for testing administration
class BarAbility
  include CanCan::Ability

  def initialize(user)
    user ||= Spree::User.new
    if user.has_spree_role? 'bar'
      # allow dispatch to :index and :show orders on the admin
      can :index, Spree::Order
      can :show, Spree::Order
      can :admin, Spree::Order
      # allow dispatch to :index, :show, :create and :update shipments on the admin
      can :manage, Spree::Shipment
      can :admin, Spree::Shipment
    end
  end
end
