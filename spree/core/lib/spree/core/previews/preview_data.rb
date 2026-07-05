# Shared fallbacks for ActionMailer previews. Everything returned here is
# in-memory (never saved) so opening a mailer preview stays read-only.
module Spree
  module PreviewData
    module_function

    # An admin user for previews that need `user.email` / `user.first_name`.
    # Falls back to an unsaved instance when the database has no admin users.
    def admin_user
      Spree.admin_user_class.first ||
        Spree.admin_user_class.new(email: 'admin@example.com', first_name: 'Alex', last_name: 'Doe')
    end
  end
end
