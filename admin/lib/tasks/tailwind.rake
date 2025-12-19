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

        def resolved_input_css
          File.read(input_path).gsub("$SPREE_ADMIN_PATH", Spree::Admin::Engine.root.to_s)
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

        command = [Tailwindcss::Ruby.executable, "-i", "-", "-o", output_path.to_s]
        command << "--minify" unless Rails.env.development? || Rails.env.test?

        puts "Building Spree Admin Tailwind CSS..."
        puts "  Input: #{Spree::Admin::TailwindHelper.input_path}"

        IO.popen(command, "w") do |io|
          io.write(Spree::Admin::TailwindHelper.resolved_input_css)
        end

        raise("Spree Admin Tailwind build failed") unless $?.success?
        puts "Done! Output: #{output_path}"
      end

      desc "Watch Spree Admin Tailwind CSS for changes"
      task watch: :environment do
        require "tailwindcss/ruby"

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        command = [Tailwindcss::Ruby.executable, "-i", "-", "-o", output_path.to_s, "--watch"]

        puts "Watching Spree Admin Tailwind CSS for changes..."
        puts "  Input: #{Spree::Admin::TailwindHelper.input_path}"

        IO.popen(command, "w") do |io|
          io.write(Spree::Admin::TailwindHelper.resolved_input_css)
        end
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
