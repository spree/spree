class OptionsController < ResourceController::Base
  belongs_to :account
  
  protected
    def parent_object
      Account.find(:first)
    end
end
