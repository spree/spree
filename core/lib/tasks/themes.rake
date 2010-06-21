namespace :spree do
  namespace :dev do
    desc "Compile non-partial less stylesheets into public/stylesheets for the last loaded theme extension."
    task :less => :environment do
      require 'less'

      #RAILS 3 TODO - figure out final resting place for less
      #$LESS_LOAD_PATH = Spree::ExtensionLoader.stylesheet_source_paths.reverse
      $LESS_LOAD_PATH = [Rails.root.join("core", "app", "stylesheets")]

      # css files are written to the last loaded theme extension's public/stylesheets directory
      output_path = $LESS_LOAD_PATH.first.to_s.gsub("app/stylesheets", "public/stylesheets")
      FileUtils.mkpath(output_path)

      # Build a list of all unique non-partial .less files to compile
      stylesheets = $LESS_LOAD_PATH.map do |path|
        Dir[  File.join(path,"[^_]*.less").to_s].map! {|f| File.basename(f) }
      end.flatten.uniq

      stylesheets.each do |less_filename|
        css_filename = less_filename.gsub(/.less/, '.css')
        paths = $LESS_LOAD_PATH.map { |p| File.join(p, less_filename) }
        if path = paths.detect {|p| File.exists?(p)}
          puts "Compiling #{less_filename} from path: #{path}"
          destination = File.join(output_path, css_filename)
          f = File.new(destination, File::CREAT|File::TRUNC|File::RDWR, 0644)
          f.write Less::Engine.new(File.new(path)).to_css
          puts "  written to #{destination}"
        end
      end

    end
  end
end
