class AccountsController < ResourceController::Singleton
  protected
    def object
      Account.find(:first)
    end
end