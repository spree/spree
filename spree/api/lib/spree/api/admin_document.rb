module Spree
  module Api
    # The Admin API's OpenAPI document as agents read it: core's `admin.yaml`
    # merged with the `openapi/admin.yaml` each extension ships in its gem.
    #
    # An extension documents its admin endpoints the way core does — rswag
    # integration specs, generated into a file — so its operations reach
    # agents, API docs and SDKs from the same contract. Nothing registers the
    # file: an engine that has one is read.
    #
    # Loaded once, lazily: core's document alone is well over a megabyte, and
    # an installation with no agent client should never pay for parsing it.
    #
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    module AdminDocument
      # Where an extension keeps its generated document, relative to its root.
      EXTENSION_PATH = File.join('openapi', 'admin.yaml')

      HTTP_VERBS = %w[get post put patch delete head options].freeze

      class << self
        # @return [Hash] the merged document
        def document
          @document ||= load_document
        end

        # Operations or components two documents describe differently. The
        # first document keeps them — core's, then extensions in load order —
        # and the later one's are left out rather than silently replacing an
        # endpoint or failing every tool; the contract spec fails on any.
        #
        # @return [Array<String>]
        def conflicts
          document
          @conflicts
        end

        # Which document an operation came from, so a contract spec can check
        # an extension against its own operations only.
        #
        # @param path [String] the OpenAPI path, e.g. `/api/v3/admin/quotes/{id}/send`
        # @param verb [String, Symbol]
        # @return [String, nil] the engine's name, or `spree_api` for core
        def source_of(path, verb)
          document
          @sources[[path, verb.to_s.downcase]]
        end

        # Forgets the parsed document only when a document file changed, so a
        # code reload in development does not re-parse a megabyte of generated
        # YAML that no edit to Ruby could have changed.
        #
        # @return [void]
        def refresh!
          current = signature
          reset! unless current == @signature
          @signature = current
        end

        # Forgets the parsed document, so the next reader loads it again.
        #
        # @return [void]
        def reset!
          @document = nil
          @sources = nil
          @conflicts = nil
        end

        # Core's generated document: `docs/` in a source checkout, or the copy
        # the release packs into the gem. Resolved lazily: the engine class
        # does not exist yet while this file loads.
        #
        # @return [Pathname]
        def core_path
          source = Spree::Api::Engine.root.join('..', '..', 'docs', 'api-reference', 'admin.yaml')
          source.exist? ? source : Spree::Api::Engine.root.join(EXTENSION_PATH)
        end

        # Every other engine that ships a document, and the application
        # itself, which may add admin endpoints of its own.
        #
        # @return [Hash{String => Pathname}] engine name => document
        def extension_paths
          engines = Rails.application.railties.grep(Rails::Engine) + [Rails.application]
          engines.each_with_object({}) do |engine, paths|
            next if engine.is_a?(Spree::Api::Engine)

            path = engine.root&.join(EXTENSION_PATH)
            next unless path&.exist?
            next if path.expand_path == core_path.expand_path

            paths[engine.engine_name] = path
          end
        end

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

          resolve_schema(component(schema['$ref']), depth + 1)
        end

        # The schema with every reference replaced by what it names, all the
        # way down, so it can be handed to a client that has no document to
        # look `$ref`s up in. A reference that leads back to itself stops at
        # an untyped object rather than recursing.
        #
        # @param schema [Object]
        # @return [Object]
        def inline(schema, seen = [])
          case schema
          when Array
            schema.map { |item| inline(item, seen) }
          when Hash
            return inline_reference(schema, seen) if schema.key?('$ref')
            return inline(merge_all_of(schema['allOf'], 0), seen) if schema.key?('allOf')

            schema.transform_values { |value| inline(value, seen) }
          else
            schema
          end
        end

        # A parameter, followed through a `$ref` to `components/parameters`.
        #
        # @param parameter [Hash]
        # @return [Hash, nil]
        def resolve_parameter(parameter)
          return parameter unless parameter.is_a?(Hash) && parameter.key?('$ref')

          document.dig('components', 'parameters', parameter['$ref'].to_s.split('/').last)
        end

        private

        def signature
          ([core_path] + extension_paths.values).map { |path| [path.to_s, (File.mtime(path) if File.exist?(path))] }
        end

        def inline_reference(schema, seen)
          reference = schema['$ref']
          return { 'type' => 'object' } if seen.include?(reference)

          target = component(reference)
          target ? inline(target, seen + [reference]) : { 'type' => 'object' }
        end

        def component(reference)
          name = reference.to_s.split('/').last
          document.dig('components', 'schemas', name)
        end

        def merge_all_of(parts, depth)
          parts.filter_map { |part| resolve_schema(part, depth + 1) }.each_with_object({}) do |part, merged|
            merged['properties'] = (merged['properties'] || {}).merge(part['properties'] || {})
            merged['required'] = (merged['required'] || []) | Array(part['required'])
          end
        end

        def load_document
          @sources = {}
          @conflicts = []
          merged = read(core_path)
          record_sources(merged, 'spree_api')

          extension_paths.each do |engine, path|
            merge!(merged, read(path), engine)
          end

          merged
        end

        # A document that is missing or does not parse is not a boot failure:
        # its operations are simply not offered, which is the safe direction.
        def read(path)
          return {} unless File.exist?(path)

          document = YAML.unsafe_load_file(path)
          return document if valid?(document)

          Rails.logger.warn("[Spree] the admin API document #{path} is not an OpenAPI document; it is ignored")
          {}
        rescue StandardError => e
          Rails.logger.warn("[Spree] could not read the admin API document #{path}: #{e.class}: #{e.message}")
          {}
        end

        # An OpenAPI document whose operations are objects: anything else
        # would raise in a reader that digs into it, on every agent request.
        def valid?(document)
          document.is_a?(Hash) && document.key?('openapi') &&
            Array(document['paths']).all? { |path, item| path.is_a?(String) && valid_path_item?(item) } &&
            (document['components'].nil? || document['components'].is_a?(Hash))
        end

        def valid_path_item?(item)
          item.is_a?(Hash) && item.all? do |key, operation|
            next true unless HTTP_VERBS.include?(key)

            operation.is_a?(Hash) && valid_request_body?(operation['requestBody'])
          end
        end

        # The catalog digs `content`, `application/json` and `schema`, so each
        # is an object where present.
        def valid_request_body?(body)
          return true if body.nil?
          return false unless body.is_a?(Hash)
          return true if body['content'].nil?
          return false unless body['content'].is_a?(Hash)

          json = body['content']['application/json']
          json.nil? || (json.is_a?(Hash) && (json['schema'].nil? || json['schema'].is_a?(Hash)))
        end

        def conflict(message)
          @conflicts << message
          Rails.logger.error("[Spree] admin API documents conflict: #{message}")
        end

        def record_sources(document, engine)
          Array(document['paths']).each do |path, operations|
            operations.each_key { |verb| @sources[[path, verb.to_s]] = engine if HTTP_VERBS.include?(verb.to_s) }
          end
        end

        def merge!(merged, addition, engine)
          merged['paths'] ||= {}
          Array(addition['paths']).each do |path, operations|
            existing = merged['paths'][path] ||= {}
            operations.each do |key, value|
              # Path-level keys (`parameters`) describe the path, not an
              # operation, and two documents for one path share them.
              next existing[key] ||= value unless HTTP_VERBS.include?(key)

              if existing.key?(key)
                conflict("#{key.upcase} #{path} is documented by both #{@sources[[path, key]]} and #{engine}")
                next
              end

              existing[key] = value
              @sources[[path, key]] = engine
            end
          end

          components = merged['components'] ||= {}
          Array(addition['components']).each do |section, definitions|
            next unless definitions.is_a?(Hash)

            existing = components[section] ||= {}
            definitions.each do |name, definition|
              if existing.key?(name) && existing[name] != definition
                conflict("the #{name} #{section.singularize} is defined differently by #{engine} and an earlier document")
                next
              end

              existing[name] = definition
            end
          end
        end
      end
    end
  end
end
