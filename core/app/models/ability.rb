class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    if user.has_role? 'admin'
      can :manage, :all
    else
      #############################
      can :read, User do |resource, token|
        resource == user
      end
      can :update, User do |resource, token|
        resource == user
      end
      can :create, User
      #############################
      can :read, Order do |order, token|
        order.user == user || (order.token == token && token)
      end
      can :update, Order do |order, token|
        order.user == user || (order.token == token && token)
      end
      can :create, Order
      #############################
      can :read, Product
      #############################
      can :read, Taxon
      #############################
    end
  end
end