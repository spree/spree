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
          css
        end

        def spree_engine_sources
          spree_engines.flat_map do |engine|
            engine_sources(engine)
          end.join("\n")
        end

        def spree_engines
          Rails::Engine.subclasses.select do |engine|
            engine.name&.start_with?("Spree::") && engine != Spree::Admin::Engine
          end
        end

        def engine_sources(engine)
          root = engine.root.to_s
          source_paths = [
            ["app/views/spree/admin", "**/*.erb"],
            ["app/helpers/spree/admin", "**/*.rb"],
            ["app/javascript/spree/admin", "**/*.js"]
          ]

          source_paths.filter_map do |dir, pattern|
            full_dir = File.join(root, dir)
            %(@source "#{full_dir}/#{pattern}";) if File.directory?(full_dir)
          end
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
