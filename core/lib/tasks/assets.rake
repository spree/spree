namespace :spree do
  namespace :assets do
    desc "Relocates files from public/assets directory"
    task :relocate_images => :environment do
      require 'fileutils'

      %w{products taxons}.each do |directory|
        depracated_assets_path = Rails.root.join("public/assets/", directory)

        if depracated_assets_path.exist?
          new_assets_path = Rails.root.join("public/spree/", directory)

          unless File.exists? new_assets_path
            puts "Creating new #{directory} images path at: #{new_assets_path}"
            FileUtils.mkdir_p(new_assets_path.to_s)
          end

          puts "Syncing files from: #{depracated_assets_path} to: #{new_assets_path}"
          Spree::Core::FileUtilz.mirror_files(depracated_assets_path.to_s, new_assets_path.to_s)


          puts "Deleting original files from: #{depracated_assets_path}"
          FileUtils.rm_rf(depracated_assets_path.to_s)
        else
          puts "No files located at: #{depracated_assets_path}"
        end

      end

      if File.exists? Rails.root.join("public/assets")
        if Dir[Rails.root.join("public/assets/*").to_s].empty?
          puts "Deleting empty public/assets directory"
          FileUtils.rm_rf(Rails.root.join("public/assets").to_s)
        end
      end

    end

    desc "Copies images from all app/assets directories into public/assets"
    task :sync_images => :environment do
      image_paths = Rails.application.assets.paths.select {|path| path.ends_with? "/images" }

      image_paths.reverse.each do |path|
        path << '/'

        Dir.glob(File.join(path, "**/*")) do |file|
          next if File.directory? file
          cache_name = Rails.root.join('public/assets', file.to_s.sub(path, ''))

          FileUtils.mkdir_p cache_name.dirname
          FileUtils.cp file, cache_name.to_s
        end
      end
    end


  end
end
