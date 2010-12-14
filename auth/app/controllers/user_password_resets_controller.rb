class UserPasswordResetsController < Devise::PasswordsController
  include SpreeBase
  helper :users, 'spree/base'

  def new
    super
  end

  def create
    super
  end

  def edit
    super
  end

  def update
    super
  end
end
