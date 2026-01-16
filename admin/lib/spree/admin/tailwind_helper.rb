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
          File.read(input_path).gsub("$SPREE_ADMIN_PATH", Spree::Admin::Engine.root.to_s)
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
