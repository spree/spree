class UserPreview < ActionMailer::Preview
  def reset_password_instructions
    Spree::UserMailer.reset_password_instructions(Spree.user_class.first, 'your_token', { current_store_id: Spree::Store.default.id })
  end

  if Spree::Auth::Config[:confirmable]
    def confirmation_instructions
      Spree::UserMailer.confirmation_instructions(Spree.user_class.first, 'your_token')
    end
  end
end
