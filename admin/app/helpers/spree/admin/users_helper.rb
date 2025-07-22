module Spree
  module Admin
    module UsersHelper
      def customer_location(user)
        address = user.billing_address || user.shipping_address || user.addresses.first

        return if address.nil?

        "#{address.city}, #{address&.state_name_text || address&.country&.to_s}"
      end

      def customer_location_flag(user)
        address = user.billing_address || user.shipping_address || user.addresses.first

        return if address.nil?

        country = address.country

        return if country.nil?

        ::Country.new(country.iso).emoji_flag
      end

      def customer_full_name(user)
        user.name&.full
      end

      def users_for_select_options
        @users_for_select_options ||= Spree.user_class.accessible_by(current_ability).pluck(:id, :email).map { |id, email| { id: id, name: email } }.as_json
      end

      def user_roles_json_array
        @user_roles_json_array ||= Spree::Role.pluck(:id, :name).map { |id, name| { id: id, name: name } }.as_json
      end
    end
  end
end
