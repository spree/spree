class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    if user.has_role? 'admin'
      can :manage, :all
    else
      #############################
      can :read, User do |resource|
        resource == user
      end
      can :update, User do |resource|
        resource == user
      end
      can :create, User
      #############################
      can :read, Order do |order|
        order.user == user
      end
      can :update, Order do |order|
        order.user == user
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