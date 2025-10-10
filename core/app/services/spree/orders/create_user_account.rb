# this service creates a user account when someone places an order
# and checks the box to create an account
module Spree
  module Orders
    class CreateUserAccount
      prepend ::Spree::ServiceModule::Base

      def call(order:, accepts_email_marketing: false)
        existing_user = Spree.user_class.find_by(email: order.email)
        return existing_user if existing_user.present?

        user = create_new_user(order, accepts_email_marketing)
        return failure(:user_creation_failed) unless user.persisted?

        assign_ship_address(order, user)
        assign_bill_address(order, user)

        # assign newly created user to the order
        # using update_columns to avoid running validations/callbacks
        order.update_columns(user_id: user.id, updated_at: Time.current)
        order.user = user

        # send welcome email
        user.send_welcome_email if user.respond_to?(:send_welcome_email)

        success(user.reload)
      end

      private

      def create_new_user(order, accepts_email_marketing = false)
        firstname = order.bill_address&.firstname || order.ship_address&.firstname
        lastname = order.bill_address&.lastname || order.ship_address&.lastname
        phone = order.bill_address&.phone || order.ship_address&.phone

        # we need to generate a password for the user
        password = SecureRandom.base58(16)

        user = Spree.user_class.new
        user.email = order.email
        user.first_name = firstname if user.respond_to?(:first_name)
        user.last_name = lastname if user.respond_to?(:last_name)
        user.phone = phone if user.respond_to?(:phone)
        user.accepts_email_marketing = accepts_email_marketing.to_b if user.respond_to?(:accepts_email_marketing)
        user.password = password if user.respond_to?(:password)
        user.password_confirmation = password if user.respond_to?(:password_confirmation)

        user.save

        user
      end

      def assign_bill_address(order, user)
        if order.bill_address.present?
          order.bill_address.update_columns(user_id: user.id, updated_at: Time.current)

          user.update_columns(bill_address_id: order.bill_address_id, updated_at: Time.current) unless user.bill_address_id.present?
        end
      end

      def assign_ship_address(order, user)
        if order.ship_address.present?
          order.ship_address.update_columns(user_id: user.id, updated_at: Time.current)

          user.update_columns(ship_address_id: order.ship_address_id, updated_at: Time.current) unless user.ship_address_id.present?
        end
      end
    end
  end
end
