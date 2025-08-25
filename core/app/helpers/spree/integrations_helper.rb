module Spree
  module IntegrationsHelper
    def store_integrations
      @store_integrations ||= Spree::Current.integrations
    end

    def store_integration(name)
      store_integrations.find { |integration| integration.type.to_s.demodulize.underscore == name }
    end

    def grouped_available_store_integrations
      Rails.application.config.spree.integrations.group_by(&:integration_group).sort_by { |group, _| group }
    end
  end
end
