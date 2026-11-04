require 'spree/api/typelizer_generation'

module Spree
  module Api
    # Generates the response types for a package that extends Spree's SDKs
    # (docs/plans/6.0-sdk-extensions.md) from an extension's own serializers,
    # with Typelizer, the way Spree generates its SDKs' types. Runs in the
    # extension's test app, through the task in sdk_types_task.rb.
    #
    # Writes `<out>/<api>/types/` for each API the extension has
    # serializers for, sorted by namespace as core's are (`::Admin::`,
    # `::Seller::`, the rest Store), and `<out>/<api>/spree.ts` beside it. The
    # generated files import every type they reference from `spree.ts`, which
    # re-exports the extension's own types and the SDK's, so a `Quote` nesting
    # an `Order` takes `Order` from `@spree/admin-sdk` instead of a copy.
    #
    # Only serializers defined under the engine's `app/serializers` are
    # written. Named value lists are written into the package, open unless
    # closed, since `@spree/sdk-core` is private to Spree's SDKs.
    module SdkTypes
      SDKS = {
        store: '@spree/sdk',
        admin: '@spree/admin-sdk',
        seller: '@spree/seller-sdk'
      }.freeze

      HEADER = '// This file is generated from the serializers by `rake spree:sdk:serializer_types`. Do not edit it.'.freeze

      class << self
        # @param engine [Class<Rails::Engine>] the extension's engine
        # @param out [String] where to write, relative to the engine's root
        # @return [Array<Symbol>] the APIs types were written for
        def generate!(engine:, out:)
          serializers = engine.root.join('app/serializers')
          out = engine.root.join(out)
          configure(serializers, out)
          refuse_name_collisions!
          # Typelizer skips a writer with no serializers and leaves its folder
          # as it was, so an API whose last serializer went away would keep
          # publishing its old types.
          SDKS.each_key do |api|
            FileUtils.rm_rf(out.join(api.to_s, 'types'))
            FileUtils.rm_f(out.join(api.to_s, 'spree.ts'))
          end
          run_typelizer

          SDKS.keys.select do |api|
            types = out.join(api.to_s, 'types')
            next false unless types.exist?

            TypelizerGeneration.use_interfaces!(types)
            File.write(out.join(api.to_s, 'spree.ts'), barrel(api))
            true
          end
        end

        # @param serializer [Class]
        # @return [Symbol] the API a serializer belongs to, by its namespace
        def api_of(serializer)
          name = serializer.name.to_s
          return :admin if name.include?('::Admin::')
          return :seller if name.include?('::Seller::')

          :store
        end

        private

        # Two serializers in one API named alike in different namespaces
        # (`Orders::ItemSerializer`, `Returns::ItemSerializer`) would write one
        # file and one type name, and a name the SDK already exports (`Order`)
        # would make `spree.ts` export two types under it.
        def refuse_name_collisions!
          SDKS.each_key do |api|
            interfaces = Typelizer.interfaces(writer_name: api)
            clash = interfaces.group_by(&:name).find { |_name, named| named.size > 1 }
            if clash
              raise ArgumentError, "#{clash.last.map { |i| i.serializer.name }.join(' and ')} both generate the #{api} type " \
                                   "#{clash.first}; rename one of the serializers"
            end

            taken = interfaces.find { |interface| core_type_names(api).include?(interface.name) }
            if taken
              raise ArgumentError, "#{taken.serializer.name} generates #{taken.name}, which #{SDKS[api]} already exports; " \
                                   'rename the serializer'
            end

            # A value list and a type of one name are both exported from the
            # generated index, and one the SDK already has would be exported
            # twice from `spree.ts`.
            names = interfaces.map(&:name).to_set
            lists = interfaces.flat_map(&:enum_types)
            list = lists.find { |property| names.include?(property.enum_type_name) }
            if list
              raise ArgumentError, "The value list #{list.enum_type_name} is also the name of a type the #{api} API generates; " \
                                   'give its enum_type_name another name'
            end

            list = lists.find { |property| core_list_names(api).include?(property.enum_type_name) }
            next unless list

            raise ArgumentError, "The value list #{list.enum_type_name}, which #{SDKS[api]} already exports, is declared again; " \
                                 'give its enum_type_name another name'
          end
        end

        # The type names Spree's own serializers give the SDK of one API, read
        # from their file names and filtered as core's writers filter them.
        def core_type_names(api)
          @core_type_names ||= {}
          @core_type_names[api] ||= begin
            root = Spree::Api::Engine.root.join('app/serializers/spree/api/v3')
            names = ->(pattern) { Dir[root.join(pattern)].to_set { |file| File.basename(file, '_serializer.rb').camelize } }
            case api
            when :store then names.call('*_serializer.rb') - TypelizerGeneration::STORE_EXCLUDED
            when :admin then names.call('admin/**/*_serializer.rb')
            when :seller then names.call('seller/**/*_serializer.rb') | TypelizerGeneration::SELLER_STORE_TYPES
            end
          end
        end

        # The value lists Spree's own serializers give the SDK of one API, read
        # from their `enum_type_name:` declarations, and the shared code lists
        # every SDK exports.
        def core_list_names(api)
          @core_list_names ||= {}
          @core_list_names[api] ||= begin
            root = Spree::Api::Engine.root.join('app/serializers/spree/api/v3')
            patterns = { store: ['*_serializer.rb'], admin: ['admin/**/*_serializer.rb', '*_serializer.rb'],
                         seller: ['seller/**/*_serializer.rb', '*_serializer.rb'] }.fetch(api)
            declared = patterns.flat_map { |pattern| Dir[root.join(pattern)] }
                               .flat_map { |file| File.read(file).scan(/enum_type_name: ['"](\w+)['"]/).flatten }
            declared.to_set | Typelizer::OpenEnums::CLOSED_TYPE_NAMES
          end
        end

        # Replaces the writers Spree configured for its own SDKs: run in an
        # extension's app, they would write core's types into the installed gem.
        def configure(serializers, out)
          ours = ->(serializer) { Object.const_source_location(serializer.name)&.first.to_s.start_with?("#{serializers}/") }

          Typelizer.configure do |config|
            config.reset_writers!
            config.dirs = [serializers]
            config.listen = false
            config.comments = true
            config.plugin_configs = TypelizerGeneration.plugin_configs
            # The default writer writes nothing; each API has its own below.
            config.reject_class = ->(serializer:) { true }

            SDKS.each_key do |api|
              config.writer(api) do |writer|
                writer.output_dir = out.join(api.to_s, 'types')
                writer.types_import_path = '../spree'
                # Named type exports compile whether or not the package sets
                # `verbatimModuleSyntax`; a default export of a type does not.
                writer.verbatim_module_syntax = true
                writer.reject_class = ->(serializer:) { !ours.call(serializer) || api_of(serializer) != api }
                writer.serializer_name_mapper = ->(serializer) { serializer.name.to_s.demodulize.delete_suffix('Serializer') }
              end
            end
          end
        end

        def run_typelizer
          disabled = ENV['DISABLE_TYPELIZER']
          source = Typelizer::OpenEnums.source
          ENV['DISABLE_TYPELIZER'] = 'false'
          Typelizer::OpenEnums.source = nil

          require 'typelizer/generator'
          Typelizer::Generator.call(force: true)
        ensure
          ENV['DISABLE_TYPELIZER'] = disabled
          Typelizer::OpenEnums.source = source
        end

        def barrel(api)
          <<~TS
            #{HEADER}

            // Every type the generated files reference: the SDK's, and this package's own.
            export type * from '#{SDKS[api]}'
            export type * from './types'
          TS
        end
      end
    end
  end
end
