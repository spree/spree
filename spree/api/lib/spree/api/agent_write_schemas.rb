module Spree
  module Api
    # The writable attribute schema for each admin resource, read from the
    # generated OpenAPI document.
    #
    # Not from the controllers: most of them declare their writable attributes
    # inside `permitted_params`, where the list is a `params.permit` call that
    # cannot be read without a request. `admin.yaml` already carries the same
    # list — generated from the integration specs, reviewed as a diff on every
    # API change — with the types, descriptions and examples a model needs to
    # fill a form in correctly. Reading it means the generic write tools offer
    # exactly the documented endpoint and nothing else.
    #
    # Loaded once, lazily: the document is well over a megabyte, and an
    # installation with no agent client should never pay for parsing it.
    module AgentWriteSchemas
      # A collection endpoint under the admin namespace: `/api/v3/admin/markets`
      # but not `/api/v3/admin/markets/{id}` or a nested child.
      COLLECTION_PATH = %r{\A/api/v3/admin/(?<key>[a-z0-9_]+)\z}

      class << self
        # The writable properties for one resource.
        #
        # @param key [String] the resource key, e.g. "markets"
        # @return [Hash] JSON Schema properties, empty when the resource has no
        #   documented write
        def for(key)
          schemas[key.to_s] || {}
        end

        # @return [Array<String>] the attribute names a write may set
        def attribute_names(key)
          self.for(key).keys
        end

        # Where the generated document lives, relative to this engine. Resolved
        # lazily: the engine class does not exist yet while this file loads.
        #
        # @return [Pathname]
        def spec_path
          Spree::Api::Engine.root.join('..', '..', 'docs', 'api-reference', 'admin.yaml')
        end

        # The parsed document, for a reader that needs more of it than the
        # write bodies — the workflow endpoint map wants the member actions'
        # bodies too, and parsing a megabyte of YAML twice is wasteful.
        #
        # @return [Hash]
        def document
          @document ||= begin
            path = spec_path
            File.exist?(path) ? (YAML.unsafe_load_file(path) || {}) : {}
          rescue StandardError => e
            Rails.logger.warn("[Spree] could not read the admin API document: #{e.class}: #{e.message}")
            {}
          end
        end

        private

        def schemas
          @schemas ||= load_schemas
        end

        # A missing or unparseable document is not a boot failure: the generic
        # write tools simply offer nothing, which is the safe direction. An
        # installation running from the packaged gems has no docs/ directory at
        # all.
        def load_schemas
          path = spec_path
          return {} unless File.exist?(path)

          document = YAML.unsafe_load_file(path)
          extract(document)
        rescue StandardError => e
          Rails.logger.warn("[Spree] could not read admin API write schemas: #{e.class}: #{e.message}")
          {}
        end

        def extract(document)
          Array(document['paths']).to_h.each_with_object({}) do |(path, operations), result|
            match = COLLECTION_PATH.match(path)
            next if match.nil?

            properties = write_properties(operations)
            result[match[:key]] = properties if properties.present?
          end
        end

        # The create body where there is one, because it documents every
        # settable attribute; an update body usually repeats a subset.
        def write_properties(operations)
          body = operations.dig('post', 'requestBody', 'content', 'application/json', 'schema')
          body ||= operations.dig('patch', 'requestBody', 'content', 'application/json', 'schema')

          resolve_schema(body)&.dig('properties').presence
        end

        public

        # A request body is declared once per endpoint and published as a
        # component, so the operation carries a `$ref` to it rather than the
        # properties themselves. A body that builds on a shared shape is an
        # `allOf` of that shape and its own fields, read as one object.
        # Followed a few hops, which is as deep as the generated document
        # nests them.
        #
        # @param schema [Hash, nil] a schema that may be a reference
        # @return [Hash, nil] the schema it names
        def resolve_schema(schema, depth = 0)
          return unless schema.is_a?(Hash)
          return if depth > 3
          return merge_all_of(schema['allOf'], depth) if schema.key?('allOf')
          return schema unless schema.key?('$ref')

          name = schema['$ref'].to_s.split('/').last
          resolve_schema(document.dig('components', 'schemas', name), depth + 1)
        end

        private

        def merge_all_of(parts, depth)
          parts.filter_map { |part| resolve_schema(part, depth + 1) }.each_with_object({}) do |part, merged|
            merged['properties'] = (merged['properties'] || {}).merge(part['properties'] || {})
            merged['required'] = (merged['required'] || []) | Array(part['required'])
          end
        end
      end
    end
  end
end
