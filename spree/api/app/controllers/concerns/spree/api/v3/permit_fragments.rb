module Spree
  module Api
    module V3
      # Combines two `params.permit` argument lists.
      #
      # Concatenating them is not enough: when both lists declare the same
      # nested key, Rails keeps only the last filter for that key, so
      # `[{ metadata: {} }] + [{ metadata: [:ext] }]` narrows `metadata` to
      # `:ext` and silently drops everything else. Merging per key avoids that.
      module PermitFragments
        module_function

        # @param lists [Array<Array>] permit fragment lists, later ones merged on top
        # @return [Array] a single fragment list safe to splat into `params.permit`
        def merge(*lists)
          scalars = []
          nested = {}

          lists.flatten(1).each do |fragment|
            if fragment.is_a?(Hash)
              fragment.each { |key, value| nested[key] = merge_values(nested[key], value) }
            elsif !scalars.include?(fragment)
              scalars << fragment
            end
          end

          nested.empty? ? scalars : scalars + [nested]
        end

        # An open hash (`{}`) permits any nested key, so it absorbs anything
        # more specific. Two arrays combine; anything else keeps the newer value.
        def merge_values(existing, incoming)
          return incoming if existing.nil?
          return existing if existing == incoming
          return {} if existing == {} || incoming == {}

          if existing.is_a?(Array) && incoming.is_a?(Array)
            merge(existing, incoming)
          elsif existing.is_a?(Hash) && incoming.is_a?(Hash)
            existing.merge(incoming) { |_key, old, new| merge_values(old, new) }
          else
            incoming
          end
        end
      end
    end
  end
end
