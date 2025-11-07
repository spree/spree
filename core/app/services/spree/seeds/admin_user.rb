module Spree
  module Seeds
    class AdminUser
      prepend Spree::ServiceModule::Base

      def call
        if Spree.admin_user_class.present? && Spree.admin_user_class.count.zero?
          user = Spree.admin_user_class.create!(
            email: ENV.fetch('ADMIN_EMAIL', 'spree@example.com'),
            password: ENV.fetch('ADMIN_PASSWORD', 'spree123'),
            password_confirmation: ENV.fetch('ADMIN_PASSWORD', 'spree123'),
            first_name: ENV.fetch('ADMIN_FIRST_NAME', 'Spree'),
            last_name: ENV.fetch('ADMIN_LAST_NAME', 'Admin')
          )
          user.save!

          Spree::Store.all.each do |store|
            store.add_user(user)
          end
        end
      end
    end
  end
end
