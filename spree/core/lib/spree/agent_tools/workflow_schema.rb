module Spree
  module AgentTools
    # Reads a workflow's argument contract and turns it into a JSON parameter
    # schema an agent can fill in.
    #
    # Nothing here is hand-maintained. `Method#parameters` on `perform` names
    # every keyword and says which are required; the YARD `@param` block above
    # it gives each one a type and a sentence of prose. Both already exist on
    # every workflow, because the house style requires them — so a workflow
    # gains a parameter and the tool's schema gains it in the same commit.
    class WorkflowSchema
      # A workflow that cannot be exposed as written. Raised at derivation time
      # so the contract spec fails in CI rather than an agent meeting a broken
      # tool in production.
      class UndocumentedParameterError < StandardError
        def initialize(workflow_class, names)
          super("#{workflow_class} exposes #{names.join(', ')} without a YARD @param — " \
                'every parameter of an exposed workflow needs a documented type')
        end
      end

      # Tenancy, which comes from the credential and never from the caller.
      # A workflow that takes `store:` is given the context's store; offering
      # it would invite a model to name another merchant's store, and the
      # answer to "which store" is the API key or the signed-in admin.
      CONTEXT_PARAMETERS = %i[store].freeze

      # Parameters the caller never supplies: they say who acted, and the
      # answer is the authenticated principal, not something a model should be
      # free to name. The adapter injects `context.principal` for whichever of
      # these the workflow takes.
      PRINCIPAL_PARAMETERS = %i[
        canceler approver reviewer refunder created_by received_by
        completed_by rejected_by accepted_by waived_by suspended_by
        invited_by requested_by resolved_by denied_by verified_by
      ].freeze

      # YARD type to JSON type. A model type is handled separately — it becomes
      # a prefixed-id string resolved through the resource map.
      PRIMITIVES = {
        'String' => 'string',
        'Symbol' => 'string',
        'Time' => 'string',
        'DateTime' => 'string',
        'Date' => 'string',
        'Boolean' => 'boolean',
        'TrueClass' => 'boolean',
        'FalseClass' => 'boolean',
        'Integer' => 'integer',
        'Numeric' => 'number',
        'Float' => 'number',
        'BigDecimal' => 'number',
        'Hash' => 'object',
        'Array' => 'array'
      }.freeze

      # @return [Class] the workflow this schema describes
      attr_reader :workflow_class

      # @param workflow_class [Class]
      # @param except [Array<Symbol>] parameters to leave out of the schema
      def initialize(workflow_class, except: [])
        @workflow_class = workflow_class
        @except = except.map(&:to_sym)
      end

      # Every parameter the caller may supply, in `perform` order.
      #
      # @return [Array<Hash>] `{name:, required:, json_type:, model_name:, description:}`
      def parameters
        @parameters ||= begin
          documented = docs
          undocumented = keywords.keys - documented.keys - injected_parameters - @except
          raise UndocumentedParameterError.new(workflow_class, undocumented) if undocumented.any?

          keywords.filter_map do |name, required|
            next if @except.include?(name) || injected_parameters.include?(name)

            build_parameter(name, required, documented.fetch(name))
          end
        end
      end

      # The principal keywords this workflow accepts, so the adapter knows
      # which to inject.
      #
      # @return [Array<Symbol>]
      def principal_parameters
        keywords.keys & PRINCIPAL_PARAMETERS
      end

      # The tenancy keywords this workflow accepts.
      #
      # @return [Array<Symbol>]
      def context_parameters
        keywords.keys & CONTEXT_PARAMETERS
      end

      # Everything filled from the context rather than by the caller.
      #
      # @return [Array<Symbol>]
      def injected_parameters
        PRINCIPAL_PARAMETERS + CONTEXT_PARAMETERS
      end

      # @return [Hash] a JSON Schema object for the tool's arguments
      def to_json_schema
        properties = parameters.to_h do |parameter|
          [parameter[:name].to_s, property_for(parameter)]
        end

        {
          type: 'object',
          properties: properties,
          required: parameters.select { |parameter| parameter[:required] }.map { |parameter| parameter[:name].to_s }
        }
      end

      private

      # `perform`'s keywords, mapped to whether they are required.
      #
      # @return [Hash{Symbol => Boolean}]
      def keywords
        @keywords ||= workflow_class.instance_method(:perform).parameters.filter_map do |kind, name|
          [name, kind == :keyreq] if %i[key keyreq].include?(kind)
        end.to_h
      end

      def build_parameter(name, required, doc)
        types = doc[:types]
        model_name = types.filter_map { |type| model_name_for(type) }.first

        json_type = model_name ? 'string' : json_type_for(types)

        {
          name: name,
          required: required,
          model_name: model_name,
          json_type: json_type,
          item_type: json_type == 'array' ? item_type_for(types) : nil,
          description: description_for(doc[:description], model_name)
        }
      end

      def property_for(parameter)
        property = { type: parameter[:json_type] }
        property[:description] = parameter[:description] if parameter[:description].present?
        property[:items] = { type: parameter[:item_type] } if parameter[:json_type] == 'array'
        property
      end

      def description_for(text, model_name)
        return text if model_name.blank?

        prefix = "Prefixed id of the #{model_name.demodulize.underscore.humanize.downcase}"
        text.present? ? "#{prefix} — #{text}" : prefix
      end

      # A Spree model, addressed by prefixed id, as its canonical class name.
      # A YARD block may name a deprecated alias (`Spree::ShippingMethod` for
      # `Spree::DeliveryMethod`), and the alias is a constant pointing at the
      # same class — so resolve the constant and ask it for its own name
      # rather than trusting the spelling.
      #
      # `Spree.admin_user_class` and the bare `Object` of a principal
      # parameter never reach here: those parameters are stripped first.
      #
      # @return [String, nil]
      def model_name_for(type)
        return unless type.start_with?('Spree::')

        constant = type.safe_constantize
        return unless constant.is_a?(Class) && constant < ActiveRecord::Base

        constant.name
      end

      # What an array holds, read from the documented type: `Array<Hash>` holds
      # objects, and anything else is treated as strings — the common case for
      # a list of names or codes.
      def item_type_for(types)
        inner = types.filter_map { |type| type[/\AArray<(.+)>\z/, 1] }.first

        PRIMITIVES[inner] || 'string'
      end

      def json_type_for(types)
        concrete = types.reject { |type| type == 'nil' }
        # `Array<Hash>` and friends — the outer container is what JSON sees.
        concrete = concrete.map { |type| type.split('<').first }
        concrete.filter_map { |type| PRIMITIVES[type] }.first || 'string'
      end

      # The YARD block above `perform`, parsed from the workflow's own source.
      #
      # Read from source rather than through the YARD gem: the gem is a
      # development dependency, and this has to work in production, where the
      # tool list is built on every request.
      #
      # @return [Hash{Symbol => Hash}]
      def docs
        @docs ||= self.class.parse_docs(workflow_class)
      end

      class << self
        # Parsed once per workflow class and cached, because a tool list is
        # built for every MCP request and the source never changes at runtime.
        #
        # @param workflow_class [Class]
        # @return [Hash{Symbol => Hash}] `{types: [String], description: String}`
        def parse_docs(workflow_class)
          cache[workflow_class.name] ||= parse_source(workflow_class)
        end

        # @return [void]
        def clear_cache!
          @cache = {}
        end

        private

        def cache
          @cache ||= {}
        end

        def parse_source(workflow_class)
          source = comment_above_perform(workflow_class)
          return {} if source.blank?

          parse_param_tags(source)
        end

        # The comment block immediately above `def perform`, joined so a
        # `@param` whose prose wraps onto the next line keeps it.
        def comment_above_perform(workflow_class)
          location = workflow_class.instance_method(:perform).source_location
          return if location.nil?

          file, line = location
          return unless File.exist?(file)

          lines = File.readlines(file)
          comment = []
          index = line - 2
          while index >= 0 && lines[index].strip.start_with?('#')
            comment.unshift(lines[index].strip.delete_prefix('#').strip)
            index -= 1
          end
          comment
        end

        def parse_param_tags(comment_lines)
          tags = {}
          current = nil

          comment_lines.each do |line|
            if (match = line.match(/\A@param\s+(\w+)\s+\[([^\]]*)\]\s*(.*)\z/))
              current = match[1].to_sym
              tags[current] = {
                types: match[2].split(',').map(&:strip).reject(&:empty?),
                description: match[3].strip
              }
            elsif line.start_with?('@')
              current = nil
            elsif current && line.present?
              tags[current][:description] = [tags[current][:description], line].reject(&:blank?).join(' ')
            end
          end

          tags
        end
      end
    end
  end
end
