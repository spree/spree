namespace :spree do
  namespace :admin do
    namespace :tailwindcss do
      desc "Build Spree Admin Tailwind CSS"
      task build: :environment do
        require "tailwindcss/ruby"

        admin_root = Spree::Admin::Engine.root
        output_path = Rails.root.join("app/assets/builds/spree/admin/application.css")

        # Ensure output directory exists
        FileUtils.mkdir_p(output_path.dirname)

        # Tailwind v4 uses CSS-first configuration via @source directives
        # No JS config file needed
        command = [
          Tailwindcss::Ruby.executable,
          "-i", admin_root.join("app/assets/tailwind/spree/admin/application.css").to_s,
          "-o", output_path.to_s
        ]

        command << "--minify" unless Rails.env.development? || Rails.env.test?

        puts "Building Spree Admin Tailwind CSS..."
        system(*command) || raise("Spree Admin Tailwind build failed")
        puts "Done! Output: #{output_path}"
      end

      desc "Watch Spree Admin Tailwind CSS for changes"
      task watch: :environment do
        require "tailwindcss/ruby"

        admin_root = Spree::Admin::Engine.root
        output_path = Rails.root.join("app/assets/builds/spree/admin/application.css")

        # Ensure output directory exists
        FileUtils.mkdir_p(output_path.dirname)

        # Tailwind v4 uses CSS-first configuration via @source directives
        # No JS config file needed
        command = [
          Tailwindcss::Ruby.executable,
          "-i", admin_root.join("app/assets/tailwind/spree/admin/application.css").to_s,
          "-o", output_path.to_s,
          "--watch"
        ]

        puts "Watching Spree Admin Tailwind CSS for changes..."
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
