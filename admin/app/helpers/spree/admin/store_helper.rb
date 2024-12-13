module Spree
  module Admin
    module StoreHelper
      include LocaleHelper

      def weight_units(store = nil)
        store ||= current_store
        if store.metric_unit_system?
          [
            [Spree.t('weight_units.kilogram'), 'kg'],
            [Spree.t('weight_units.gram'), 'g']
          ]
        else
          [
            [Spree.t('weight_units.pound'), 'lb'],
            [Spree.t('weight_units.ounce'), 'oz']
          ]
        end
      end

      def dimensions_units(store = nil)
        store ||= current_store

        if store.metric_unit_system?
          [
            [Spree.t('dimensions_units.centimeter'), 'cm'],
            [Spree.t('dimensions_units.millimeter'), 'mm']
          ]
        else
          [
            [Spree.t('dimensions_units.inch'), 'in'],
            [Spree.t('dimensions_units.foot'), 'ft']
          ]
        end
      end

      def unit_systems
        [
          [Spree.t('unit_systems.metric_system'), 'metric'],
          [Spree.t('unit_systems.imperial_system'), 'imperial']
        ]
      end

      def legal_policy(store = nil, policy: 'privacy_policy')
        store ||= current_store if defined?(current_store)
        return unless store

        store.send("customer_#{policy}")&.body&.html_safe
      end
    end
  end
end
