module Spree
  module Admin
    module TailwindHelper
      class << self
        def input_path
          Rails.root.join("app/assets/tailwind/spree_admin.css")
        end

        def output_path
          Rails.root.join("app/assets/builds/spree/admin/application.css")
        end

        def resolved_input_path
          Rails.root.join("tmp/tailwind/spree_admin_resolved.css")
        end

        def engine_css_path
          Spree::Admin::Engine.root.join("app/assets/tailwind")
        end

        def resolved_input_css
          css = File.read(input_path)
          css = css.gsub("$SPREE_ADMIN_PATH", Spree::Admin::Engine.root.to_s)
          css = css.gsub("/* $SPREE_ENGINE_SOURCES */", spree_engine_sources)

          # Resolve relative @source paths to absolute paths since the resolved
          # CSS is written to tmp/ which changes the relative path base
          source_base = input_path.dirname
          css = css.gsub(%r{@source\s+"(\.\./[^"]+)"}) do |_match|
            relative = Regexp.last_match(1)
            absolute = File.expand_path(relative, source_base)
            %(@source "#{absolute}")
          end

          css
        end

        def spree_engine_sources
          spree_engines.flat_map do |engine|
            engine_sources(engine)
          end.join("\n")
        end

        def spree_engines
          Rails::Engine.subclasses.select do |engine|
            engine.name&.start_with?("Spree")
          end
        end

        # [relative dir, glob] pairs Tailwind scans for utility classes.
        SOURCE_PATHS = [
          ["app/views/spree/admin", "**/*.erb"],
          ["app/helpers/spree/admin", "**/*.rb"],
          ["app/javascript/spree/admin", "**/*.js"]
        ].freeze

        def engine_sources(engine)
          root = engine.root.to_s

          SOURCE_PATHS.filter_map do |dir, pattern|
            full_dir = File.join(root, dir)
            %(@source "#{full_dir}/#{pattern}";) if File.directory?(full_dir)
          end
        end

        # Every template/CSS glob that affects the compiled admin CSS, across all
        # Spree engines plus the host app. Used by watch mode to poll for changes
        # (OS file-system events don't cross a Docker bind mount from a macOS host).
        #
        # @return [Array<String>] absolute Dir.glob patterns
        def source_globs
          roots = spree_engines.map { |engine| engine.root.to_s }
          roots << Rails.root.to_s

          template_globs = roots.product(SOURCE_PATHS).map do |root, (dir, pattern)|
            File.join(root, dir, pattern)
          end

          css_globs = [engine_css_path.to_s, input_path.dirname.to_s].map do |dir|
            File.join(dir, "**", "*.css")
          end

          (template_globs + css_globs).uniq
        end

        def write_resolved_css
          FileUtils.mkdir_p(resolved_input_path.dirname)
          File.write(resolved_input_path, resolved_input_css)
          resolved_input_path
        end
      end
    end
  end
end
