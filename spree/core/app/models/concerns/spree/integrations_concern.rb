module Spree
  # @deprecated Use {Spree::Current.integrations}; removed in Spree 6.1.
  #
  # Nothing in Spree calls these — the per-request integration set lives on
  # {Spree::Current} — but the concern sits on Spree::Base, so every model has
  # carried the methods as public surface since they shipped.
  module IntegrationsConcern
    def store_integrations
      Spree::Deprecation.warn(
        'Spree::IntegrationsConcern#store_integrations is deprecated and will be removed in Spree 6.1. '         'Use Spree::Current.integrations instead.'
      )

      Spree::Current.integrations
    end

    def store_integration(name)
      Spree::Deprecation.warn(
        'Spree::IntegrationsConcern#store_integration is deprecated and will be removed in Spree 6.1. '         'Use Spree::Current.integrations.find { |integration| integration.type.to_s.demodulize.underscore == name } instead.'
      )

      Spree::Current.integrations.find { |integration| integration.type.to_s.demodulize.underscore == name }
    end
  end
end
