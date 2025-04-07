module Spree
  module IntegrationsHelper
    def store_integrations
      @store_integrations ||= current_store.integrations.active.to_a
    end

    def store_integration(name)
      store_integrations.find { |integration| integration.type.to_s.demodulize.underscore == name }
    end

    def available_store_integrations
      Rails.application.config.spree.integrations
    end
  end
end
