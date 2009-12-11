# Patches for the 'more' plugin which adds LessCSS Support to Rails
# We need more to be able to load stylesheets from app/stylesheets in
# each extension then write them to the same destination. Where stylesheets
# of the same name exist in different extensions, the file in the last 
# extension to be loaded takes precedence allowing them to be overriden
# in the same manner as views

class Less::More
  
  class << self

    def source_paths
      @source_paths || [source_path]
    end
    def source_paths=(paths_array)
      @source_paths = paths_array.map{|p| Pathname.new(p.to_s)}
    end

    # Override because this method would only generate if .css file didnt exist for path_as_array
    # and we want to force re-compilation of a less file, overwriting css
    def generate(path_as_array)
      source = pathname_from_array(path_as_array)
      if source.extname == ".css"
        css = File.read(source)
      else
        css = generate_css(source)
      end
      css
    end
    
    def generate_css(source)
      engine = File.open(source) {|f| Less::Engine.new(f) }
      css = engine.to_css
      css.delete!("\n") if self.compression?
      css = (HEADER % [source.to_s]) << css if self.header?
      css
    end


    # If .less file, compile CSS for same directory as a cache
    def compile(path_as_array)
      source = pathname_from_filename(path_as_array.to_s + '.less')
      return if source.nil?
      unless source.extname == ".css"
        destination = Pathname.new(source.to_s.gsub(/.less$/, '.css'))

        if !File.exists?(destination) || source.mtime > destination.mtime
          css = Less::More.generate_css(source)
          File.open(destination, "w") {|f|
            f.puts css
          }
        end
      end
    end
    
    def needs_recompiling?(source)
      if source.extname == ".css"
        return false
      else
        
      end
    end
    
            
    # Array of Pathname instances for all the less source files.
    def all_less_files
      #Dir[Less::More.source_path.join("**", "*.{css,less,lss}")].map! {|f| Pathname.new(f) }
      source_paths.map do |pathname|
        all_less_files_in_path(pathname)
      end.flatten
    end
    
    def all_less_files_in_path(pathname)
      Dir[pathname.join("**", "*.{css,less,lss}")].map! {|f| Pathname.new(f) }
    end


    # Generates all the .css files.
    # Override to iterate through all source paths
    def parse
      source_paths.reverse.each do |source_path|
        Less::More.all_less_files_in_path(source_path).each do |path|
          # Get path
          relative_path = path.relative_path_from(source_path)
          path_as_array = relative_path.to_s.split(File::SEPARATOR)
          path_as_array[-1] = File.basename(path_as_array[-1], File.extname(path_as_array[-1]))

          # Generate CSS
          css = Less::More.generate(path_as_array)

          # Store CSS
          path_as_array[-1] = path_as_array[-1] + ".css"
          destination = Pathname.new(File.join(Rails.root, "public", Less::More.destination_path)).join(*path_as_array)
          destination.dirname.mkpath

          File.open(destination, "w") {|f|
            f.puts css
          }
        end
      end
    end

    # Override to look in each of the source paths. Return pathname for first source path that contains this file
    def pathname_from_array(array)
      path_spec = array.dup
      path_spec[-1] = path_spec[-1] + ".{css,less,lss}"
      self.source_paths.map do |source_path|
        Pathname.glob(File.join(source_path.to_s, *path_spec))[0]
      end.compact.first
    end

    # Find pathname for specific filename in each of the source paths
    def pathname_from_filename(filename)
      self.source_paths.map do |source_path|
        Pathname.glob(File.join(source_path.to_s, filename))[0]
      end.compact.first
    end  

  end

end

Less.source_paths = Less::More.source_paths = Spree::ExtensionLoader.stylesheet_source_paths.reverse
