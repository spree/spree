require 'spree/admin/tailwind_helper'

namespace :spree do
  namespace :admin do
    namespace :tailwindcss do
      desc "Build Spree Admin Tailwind CSS"
      task build: :environment do
        require "tailwindcss/ruby"

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        # Write resolved CSS to temp file
        resolved_path = Spree::Admin::TailwindHelper.write_resolved_css

        command = [Tailwindcss::Ruby.executable, "-i", resolved_path.to_s, "-o", output_path.to_s]
        command << "--minify" unless Rails.env.development? || Rails.env.test?

        puts "Building Spree Admin Tailwind CSS..."
        puts "  Input: #{Spree::Admin::TailwindHelper.input_path}"
        puts "  Resolved: #{resolved_path}"

        system(*command)
        raise("Spree Admin Tailwind build failed") unless $?.success?
        puts "Done! Output: #{output_path}"
      end

      desc "Watch Spree Admin Tailwind CSS for changes"
      task watch: :environment do
        require "tailwindcss/ruby"

        begin
          require "listen"
        rescue LoadError
          puts "ERROR: The 'listen' gem is required for watch mode."
          puts "Add it to your Gemfile in the development group:"
          puts ""
          puts "  group :development do"
          puts "    gem 'listen', '>= 3.0'"
          puts "  end"
          puts ""
          exit 1
        end

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        # Initial write of resolved CSS
        resolved_path = Spree::Admin::TailwindHelper.write_resolved_css
        puts "Watching Spree Admin Tailwind CSS for changes..."
        puts "  Host input: #{Spree::Admin::TailwindHelper.input_path}"
        puts "  Engine CSS: #{Spree::Admin::TailwindHelper.engine_css_path}"
        puts "  Resolved: #{resolved_path}"
        puts "  Output: #{output_path}"

        # Watch paths for CSS source changes
        watch_paths = [
          Spree::Admin::TailwindHelper.engine_css_path.to_s,  # Engine CSS files
          Spree::Admin::TailwindHelper.input_path.dirname.to_s # Host app CSS files
        ].select { |p| File.directory?(p) }

        # Set up listener to regenerate resolved CSS when source files change
        listener = Listen.to(*watch_paths, only: /\.css$/) do |modified, added, removed|
          changed = (modified + added + removed).map { |f| File.basename(f) }.join(", ")
          puts "\n[#{Time.now.strftime('%H:%M:%S')}] CSS changed: #{changed}"
          puts "  Regenerating resolved CSS..."
          Spree::Admin::TailwindHelper.write_resolved_css
        end
        listener.start

        # Run Tailwind in watch mode (this blocks)
        command = [
          Tailwindcss::Ruby.executable,
          "-i", resolved_path.to_s,
          "-o", output_path.to_s,
          "--watch"
        ]

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
