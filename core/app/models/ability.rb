class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.has_role? 'admin'
      can :manage, :all
    else
      # User permissions
      can :read, User do |user_resource|
        user_resource == user
      end
      can :update, User do |user_resource|
        user_resource == user
      end
      can :create, User
      # Order permissions
      can :read, Order do |order|
        order.user == user
      end
      can :update, Order do |order|
        order.user == user
      end
      can :create, Order
    end
  end
end