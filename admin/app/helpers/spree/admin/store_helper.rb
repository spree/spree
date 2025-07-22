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

      def dimension_units(store = nil)
        store ||= current_store

        if store.metric_unit_system?
          [
            [Spree.t('dimension_units.centimeter'), 'cm'],
            [Spree.t('dimension_units.millimeter'), 'mm']
          ]
        else
          [
            [Spree.t('dimension_units.inch'), 'in'],
            [Spree.t('dimension_units.foot'), 'ft']
          ]
        end
      end

      def unit_systems
        [
          [Spree.t('unit_systems.metric_system'), 'metric'],
          [Spree.t('unit_systems.imperial_system'), 'imperial']
        ]
      end
    end
  end
end
