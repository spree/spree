module Spree
  module Core
    # Re-applies the `metafields` relationship to the V2 Platform serializers
    # once `Spree.metafields.enabled_resources` is finally filled.
    #
    # The platform ResourceSerializerConcern decides at serializer CLASS-LOAD
    # time whether to declare the relationship, by reading a list this engine
    # seeds EMPTY in the 'spree.register.metafields' initializer and only
    # fills in `config.after_initialize`. Rails boots initializers →
    # to_prepare → eager loading → after_initialize, so under production
    # eager loading every platform serializer class loads between those two
    # moments, evaluates the gate against the empty list and permanently
    # misses the relationship: `?include=metafields` returns 400 on every
    # platform endpoint, while development's lazy loading (classes load on
    # first request, after the list is filled) hides the gap.
    #
    # Called from the engine's after_initialize, right after the list is
    # assigned. Idempotent; a no-op for serializers that already carry the
    # relationship (lazy-loaded boots) and for apps without the platform API.
    class MetafieldsSerializerBackfill
      def self.call(resources = Spree.metafields.enabled_resources)
        Array(resources).each do |model|
          next unless model.respond_to?(:method_defined?) && model.method_defined?(:metafields)

          serializer = "Spree::Api::V2::Platform::#{model.name.demodulize}Serializer".safe_constantize
          next if serializer.nil? || !serializer.respond_to?(:has_many)
          next if serializer.respond_to?(:relationships_to_serialize) && serializer.relationships_to_serialize&.key?(:metafields)

          serializer.has_many :metafields, serializer: Spree.api.platform_metafield_serializer,
                                           record_type: :metafield,
                                           object_method_name: :metafields
        end
      end
    end
  end
end
