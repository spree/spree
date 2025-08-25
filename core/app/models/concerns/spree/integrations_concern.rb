module Spree
  module IntegrationsConcern
    def store_integrations
      @store_integrations ||= Spree::Current.integrations
    end

    def store_integration(name)
      store_integrations.find { |integration| integration.type.to_s.demodulize.underscore == name }
    end
  end
end
