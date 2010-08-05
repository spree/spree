class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.has_role? 'admin'
      can :manage, :all
    else
      can :read, User do |user_resource|
        user_resource == user
      end
      can :update, User do |user_resource|
        user_resource == user
      end
      can :create, User
    end
  end
end