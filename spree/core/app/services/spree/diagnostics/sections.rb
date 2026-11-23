module Spree
  class Diagnostics
    # The sections core ships. Extensions add their own through
    # {Spree.diagnostics_sections}.
    module Sections
      class Platform < Section
        def title = 'Spree'

        def rows
          {
            'Version' => -> { ::Spree.version },
            'Gems' => -> { Stack.spree_gems.map { |name, version| "#{name} #{version}" } },
            'Other gems built on Spree' => -> { extensions }
          }
        end

        private

        # Only a count: the other gems built on Spree are often the merchant's
        # own, private ones, and their names don't belong in a public issue.
        def extensions
          listed = Stack.spree_gems
          Gem.loaded_specs.values.count do |spec|
            !listed.key?(spec.name) && (Stack.spree_gem?(spec) || spec.runtime_dependencies.any? { |dependency| listed.key?(dependency.name) })
          end
        end
      end

      class Runtime < Section
        def title = 'Runtime'

        def rows
          {
            'Ruby' => -> { "#{RUBY_VERSION} (#{RUBY_PLATFORM})" },
            'Rails' => -> { Rails.version },
            'Environment' => -> { Rails.env },
            'Operating system' => -> { operating_system },
            'Web server' => -> { web_server }
          }
        end

        private

        def operating_system
          uname = Etc.uname
          "#{uname[:sysname]} #{uname[:release]} #{uname[:machine]}"
        end

        def web_server
          "Puma #{::Puma::Const::PUMA_VERSION}" if defined?(::Puma::Const::PUMA_VERSION)
        end
      end

      class Infrastructure < Section
        def title = 'Infrastructure'

        def rows
          {
            'Database' => -> { [Stack.database, database_version].compact.join(' ') },
            'Queue adapter' => -> { ActiveJob::Base.queue_adapter_name },
            'Cache store' => -> { Rails.cache.class.name.demodulize.underscore },
            'File storage' => -> { Rails.application.config.active_storage.service }
          }
        end

        private

        # PostgreSQL reports 180006 for 18.6.
        def database_version
          version = ActiveRecord::Base.connection.database_version
          version.is_a?(Integer) ? "#{version / 10_000}.#{version % 10_000}" : version.to_s
        end
      end

      # Settings changed from their defaults. Only flags, numbers and
      # fixed-choice strings are shown: free-form strings can hold URLs,
      # names or credentials, so they are never reported, whatever they are.
      class Preferences < Section
        REPORTABLE_TYPES = %i[boolean integer decimal].freeze

        def title = 'Changed settings'

        def rows
          config_rows.merge(store_rows)
        end

        private

        def config_rows
          config = ::Spree::Config
          config.class.types.each_with_object({}) do |(name, type), rows|
            next if config.class.deprecations[name] || REPORTABLE_TYPES.exclude?(type)

            rows["config.#{name}"] = lambda do
              value = config.get(name)
              value unless value == config.class.defaults[name]
            end
          end
        end

        def store_rows
          store.class.preference_definitions.each_with_object({}) do |(name, definition), rows|
            next unless reportable?(name, definition)

            rows["store.#{name}"] = lambda do
              value = store.get_preference(name)
              value unless value == store.preference_default(name)
            end
          end
        end

        def reportable?(name, definition)
          return false if definition[:internal] || definition[:deprecated]

          REPORTABLE_TYPES.include?(definition[:type]) ||
            (definition[:type] == :string && store.preference_choices(name).is_a?(Array))
        end
      end
    end
  end
end
