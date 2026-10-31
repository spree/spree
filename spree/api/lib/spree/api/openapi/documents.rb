require 'fileutils'

module Spree
  module Api
    module OpenAPI
      # The generated API references the agent tools read at runtime.
      #
      # They are written to `docs/api-reference/`, which the published gems
      # do not ship, so `rake gem:build` copies them into the gem's own
      # `openapi/` directory. A source checkout reads `docs/` directly, so a
      # freshly regenerated reference is never shadowed by an old copy.
      module Documents
        NAMES = %w[admin store].freeze

        GEM_ROOT = File.expand_path('../../../..', __dir__)
        SOURCE_DIR = File.expand_path('../../docs/api-reference', GEM_ROOT)
        BUNDLED_DIR = File.join(GEM_ROOT, 'openapi')

        class << self
          # @param name [String] `admin` or `store`
          # @return [String] where the document is, preferring the source
          #   checkout over the copy packed into the gem
          def path(name)
            source = File.join(SOURCE_DIR, "#{name}.yaml")
            File.exist?(source) ? source : File.join(BUNDLED_DIR, "#{name}.yaml")
          end

          # Copies every document into the gem before it is built. Fails
          # rather than build a gem whose agent tools would offer nothing.
          def bundle!
            FileUtils.mkdir_p(BUNDLED_DIR)
            NAMES.each do |name|
              source = File.join(SOURCE_DIR, "#{name}.yaml")
              raise "#{source} is missing; it must be packed into spree_api" unless File.exist?(source)

              FileUtils.cp(source, BUNDLED_DIR)
            end
          end
        end
      end
    end
  end
end
