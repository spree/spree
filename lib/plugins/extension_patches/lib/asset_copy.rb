require 'fileutils'
require 'spree/extension'

module Spree
  class FileUtilz            
    # A general purpose method to mirror a directory (+source+) into a destination
    # directory, including all files and subdirectories. Files will not be mirrored
    # if they are identical already (checked via FileUtils#identical?).
    #
    # Copyright (c) 2008 James Adam (The MIT License)
    def self.mirror_files(source, destination)
      return unless File.directory?(source)
    
      # TODO: use Rake::FileList#pathmap?    
      source_files = Dir[source + "/**/*"]
      source_dirs = source_files.select { |d| File.directory?(d) }
      source_files -= source_dirs
    
      unless source_files.empty?
        base_target_dir = File.join(destination)
        FileUtils.mkdir_p(base_target_dir)
      end
    
      source_dirs.each do |dir|
        # strip down these paths so we have simple, relative paths we can
        # add to the destination
        target_dir = File.join(destination, dir.gsub(source, ''))
        begin        
          FileUtils.mkdir_p(target_dir)
        rescue Exception => e
          raise "Could not create directory #{target_dir}: \n" + e
        end
      end
    
      source_files.each do |file|
        begin
          target = File.join(destination, file.gsub(source, ''))
          unless File.exist?(target) && FileUtils.identical?(file, target)
            FileUtils.cp(file, target)
          end 
        rescue Exception => e
          raise "Could not copy #{file} to #{target}: \n" + e 
        end
      end  
    end   
  end
end

# copy the assets from extensions public dir into #{RAILS_ROOT}/public
destination = "#{RAILS_ROOT}/public"
paths_to_mirror = Spree::ExtensionLoader.instance.load_extension_roots

paths_to_mirror.each do |extension_path|
  source = "#{extension_path}/public"
  if File.directory?(source)
    begin
      RAILS_DEFAULT_LOGGER.info "INFO: Mirroring assets from #{source} to #{destination}"
      Spree::FileUtilz.mirror_files(source, destination)
    rescue LoadError, NameError => e
      $stderr.puts "Could not copy extension assets from : #{source}.\n#{e.inspect}"
      nil
    end
  end
end  

