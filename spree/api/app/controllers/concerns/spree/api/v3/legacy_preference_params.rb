module Spree
  module Api
    module V3
      # Accepts a setting under its pre-6.0 `preferred_<name>` key for one
      # release, with a deprecation warning, so a client written for 5.x keeps
      # saving instead of having its change silently dropped. Responses use
      # only the plain name. Removed in Spree 6.1.
      module LegacyPreferenceParams
        extend ActiveSupport::Concern

        class_methods do
          # @param model [Class] the model whose exposed preferences the controller writes
          def accepts_legacy_preference_params(model)
            before_action(if: -> { request.post? || request.patch? || request.put? }) { translate_legacy_preference_params(model) }
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
      end
    end
  end
end
