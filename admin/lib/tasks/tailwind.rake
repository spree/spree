module Spree
  module Admin
    module TailwindHelper
      class << self
        # Returns the input CSS path from the host app
        # Created by the install generator (rails g spree:admin:install)
        def input_path
          Rails.root.join("app/assets/tailwind/spree_admin.css")
        end

        def output_path
          Rails.root.join("app/assets/builds/spree/admin/application.css")
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

        input_path = Spree::Admin::TailwindHelper.input_path
        output_path = Spree::Admin::TailwindHelper.output_path

        # Ensure output directory exists
        FileUtils.mkdir_p(output_path.dirname)

        command = [
          Tailwindcss::Ruby.executable,
          "-i", input_path.to_s,
          "-o", output_path.to_s
        ]

        command << "--minify" unless Rails.env.development? || Rails.env.test?

        puts "Building Spree Admin Tailwind CSS..."
        puts "  Input: #{input_path}"
        system(*command) || raise("Spree Admin Tailwind build failed")
        puts "Done! Output: #{output_path}"
      end

      desc "Watch Spree Admin Tailwind CSS for changes"
      task watch: :environment do
        require "tailwindcss/ruby"

        input_path = Spree::Admin::TailwindHelper.input_path
        output_path = Spree::Admin::TailwindHelper.output_path

        # Ensure output directory exists
        FileUtils.mkdir_p(output_path.dirname)

        command = [
          Tailwindcss::Ruby.executable,
          "-i", input_path.to_s,
          "-o", output_path.to_s,
          "--watch"
        ]

        puts "Watching Spree Admin Tailwind CSS for changes..."
        puts "  Input: #{input_path}"
        system(*command)
      end
    end
  end
end

# Override the default tailwindcss:build task from tailwindcss-rails gem.
# Spree Admin handles its own Tailwind build, so we make the default task
# a no-op unless the host app has additional Tailwind CSS outside of Spree Admin.
if Rake::Task.task_defined?("tailwindcss:build")
  Rake::Task["tailwindcss:build"].clear

  namespace :tailwindcss do
    desc "Build Tailwind CSS (overridden by Spree Admin)"
    task build: :environment do
      # Spree Admin's tailwind build handles everything through spree:admin:tailwindcss:build
      # This task is intentionally empty to prevent the default tailwindcss-rails behavior
      # which would fail if app/assets/tailwind/application.css doesn't exist in the host app.
      #
      # If you have host app CSS that needs separate compilation, you can:
      # 1. Add your styles to app/assets/tailwind/application.css and let Spree Admin compile it
      # 2. Create a separate rake task for your host app's CSS
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
