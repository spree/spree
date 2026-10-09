module Spree
  module Api
    module V3
      # Accepts the pre-6.0 shapes of a write for one release, with a
      # deprecation warning, so a client written for 5.x keeps saving instead
      # of having its change silently dropped: a setting under its
      # `preferred_<name>` key, and a calculator as `calculator_type` plus
      # `calculator_preferences`. Responses use only the new shapes. Removed
      # in Spree 6.1.
      module LegacyPreferenceParams
        extend ActiveSupport::Concern

        class_methods do
          # @param model [Class] the model whose exposed preferences the controller writes
          def accepts_legacy_preference_params(model)
            before_action(if: -> { request.post? || request.patch? || request.put? }) { translate_legacy_preference_params(model) }
          end

          def accepts_legacy_calculator_params
            before_action(if: -> { request.post? || request.patch? || request.put? }) { translate_legacy_calculator_params }
          end
        end

        private

        def translate_legacy_preference_params(model)
          params.keys.each do |key|
            name = model.exposed_preference_name(key)&.to_s
            next if name.nil? || params.key?(name)

            Spree::Deprecation.warn("The `#{key}` parameter is deprecated and will be removed in Spree 6.1. Send `#{name}` instead.")
            params[name] = params.delete(key)
          end
        end

        def translate_legacy_calculator_params
          return if params.key?(:calculator) || !(params.key?(:calculator_type) || params.key?(:calculator_preferences))

          Spree::Deprecation.warn(
            'The `calculator_type` and `calculator_preferences` parameters are deprecated and will be removed in Spree 6.1. ' \
            'Send `calculator: { type, preferences }` instead.'
          )
          params[:calculator] = { type: params.delete(:calculator_type), preferences: params.delete(:calculator_preferences) }.compact
        end
      end
    end
  end
end
