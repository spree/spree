module Spree
  module IntegrationsHelper
    def store_integrations
      @store_integrations ||= current_store.integrations.active.to_a
    end

    def store_integration(name)
      store_integrations.find { |integration| integration.type.to_s.demodulize.underscore == name }
    end

    def grouped_available_store_integrations
      Spree.integrations.group_by(&:integration_group).sort_by { |group, _| group }
    end
  end
end
