# Fake ability for testing administration
class BarAbility
  include CanCan::Ability

  def initialize(user)
    user ||= Spree::User.new
    if user.has_role? 'bar'
      # allow dispatch to :index and :show orders on the admin
      can :index, Order
      can :show, Order
      can :admin, Order
      # allow dispatch to :index, :show, :create and :update shipments on the admin
      can :manage, Shipment
      can :admin, Shipment
    end
  end
end