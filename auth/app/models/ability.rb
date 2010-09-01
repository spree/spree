class Ability
  include CanCan::Ability

  def initialize(user)
    self.clear_aliased_actions

    # override cancan default aliasing (we don't want to differentiate between read and index)
    alias_action :edit, :to => :update
    alias_action :new, :to => :create
    alias_action :show, :to => :read

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
      can :index, Product
      #############################
      can :read, Taxon
      can :index, Taxon
      #############################
    end
  end
end