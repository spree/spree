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
          Spree::Admin::Engine.root.join("app/assets/builds/spree_admin_resolved.css")
        end

        def resolved_input_css
          File.read(input_path).gsub("$SPREE_ADMIN_PATH", Spree::Admin::Engine.root.to_s)
        end

        # Write resolved CSS to a temp file in the gem directory
        # This ensures @source directives with relative paths resolve correctly
        def write_resolved_input!
          FileUtils.mkdir_p(resolved_input_path.dirname)
          File.write(resolved_input_path, resolved_input_css)
          resolved_input_path
        end
      end
    end
  end
end

namespace :spree do
  namespace :admin do
    namespace :tailwindcss do
      desc "Build Spree Admin Tailwind CSS"
      task build: :environment do
        require "tailwindcss/ruby"

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        # Write resolved CSS to temp file in gem directory so relative @source paths work
        resolved_input = Spree::Admin::TailwindHelper.write_resolved_input!

        command = [
          Tailwindcss::Ruby.executable,
          "-i", resolved_input.to_s,
          "-o", output_path.to_s,
          "--cwd", Spree::Admin::Engine.root.join("app/assets/tailwind/spree/admin").to_s
        ]
        command << "--minify" unless Rails.env.development? || Rails.env.test?

        puts "Building Spree Admin Tailwind CSS..."
        puts "  Input: #{Spree::Admin::TailwindHelper.input_path}"

        system(*command)

        raise("Spree Admin Tailwind build failed") unless $?.success?
        puts "Done! Output: #{output_path}"
      end

      desc "Watch Spree Admin Tailwind CSS for changes"
      task watch: :environment do
        require "tailwindcss/ruby"

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        # Write resolved CSS to temp file in gem directory so relative @source paths work
        resolved_input = Spree::Admin::TailwindHelper.write_resolved_input!

        command = [
          Tailwindcss::Ruby.executable,
          "-i", resolved_input.to_s,
          "-o", output_path.to_s,
          "--cwd", Spree::Admin::Engine.root.join("app/assets/tailwind/spree/admin").to_s,
          "--watch"
        ]

        puts "Watching Spree Admin Tailwind CSS for changes..."
        puts "  Input: #{Spree::Admin::TailwindHelper.input_path}"

        system(*command)
      end
    end
  end
end

# Hook into assets:precompile
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["spree:admin:tailwindcss:build"])
end

# Hook into test preparation tasks
%w[test:prepare spec:prepare db:test:prepare].each do |task_name|
  if Rake::Task.task_defined?(task_name)
    Rake::Task[task_name].enhance(["spree:admin:tailwindcss:build"])
  end
end
