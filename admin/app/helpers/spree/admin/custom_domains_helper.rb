module Spree
  module Admin
    module CustomDomainsHelper
      def entri_enabled?
        defined?(Entri) && Rails.application.credentials.dig(:entri, :app_id).present? && Rails.application.credentials.dig(:entri, :secret).present?
      end
    end
  end
end
