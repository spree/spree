class Ability
  include CanCan::Ability
  def initialize(user)
    can :manage, :all
  end  
end

Spree::BaseController.class_eval do
  def current_user
    User.new
  end
end
