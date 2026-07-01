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

        output_path = Spree::Admin::TailwindHelper.output_path
        FileUtils.mkdir_p(output_path.dirname)

        resolved_path = Spree::Admin::TailwindHelper.resolved_input_path

        # One-shot Tailwind build. Polling drives recompilation instead of
        # Tailwind's own --watch: its file watching (like the `listen` gem's)
        # relies on OS file-system events, which don't cross a Docker bind mount
        # from a macOS host, so a host-side template edit would never rebuild.
        build = lambda do
          Spree::Admin::TailwindHelper.write_resolved_css
          system(Tailwindcss::Ruby.executable, "-i", resolved_path.to_s, "-o", output_path.to_s)
        end

        source_mtimes = lambda do
          Spree::Admin::TailwindHelper.source_globs.each_with_object({}) do |glob, acc|
            Dir.glob(glob).each do |file|
              acc[file] = File.mtime(file) rescue next
            end
          end
        end

        puts "Watching Spree Admin Tailwind CSS for changes..."
        puts "  Host input: #{Spree::Admin::TailwindHelper.input_path}"
        puts "  Engine CSS: #{Spree::Admin::TailwindHelper.engine_css_path}"
        puts "  Resolved: #{resolved_path}"
        puts "  Output: #{output_path}"

        build.call
        previous = source_mtimes.call

        loop do
          sleep 1
          begin
            current = source_mtimes.call
            next if current == previous

            changed = (current.keys | previous.keys).select { |f| current[f] != previous[f] }
                      .map { |f| File.basename(f) }.uniq.first(5).join(", ")
            previous = current
            puts "\n[#{Time.now.strftime('%H:%M:%S')}] Sources changed: #{changed} — rebuilding..."
            build.call
          rescue => e
            # A transient read/build error (e.g. a source file caught mid-save)
            # must not kill the watch loop — log and keep polling.
            warn "[tailwind watch] rebuild failed: #{e.class}: #{e.message}"
          end
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
