module Spree
  module Admin
    module PreferencesConcern
      extend ActiveSupport::Concern

      private

      def clear_empty_password_preferences(param_name)
        if params[param_name].present?
          password_preferences = @object.preferences_of_type(:password)
          password_preferences.each do |preference|
            preference_key = "preferred_#{preference}"

            if params.dig(param_name, preference_key).blank? && @object.preferences[preference].present?
              params[param_name].delete(preference_key)
            end
          end
        end
      end
    end
  end
end
