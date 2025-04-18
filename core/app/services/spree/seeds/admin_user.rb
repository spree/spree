module Spree
  module Seeds
    class AdminUser
      prepend Spree::ServiceModule::Base

      def call
        if Spree.admin_user_class.present? && Spree.admin_user_class.count.zero?
          user = Spree.admin_user_class.create!(
            email: 'spree@example.com',
            password: 'spree123',
            password_confirmation: 'spree123',
            first_name: 'Spree',
            last_name: 'Admin'
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
