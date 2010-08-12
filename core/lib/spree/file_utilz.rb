require 'fileutils'

module Spree
  class FileUtilz
    # A general purpose method to mirror a directory (+source+) into a destination
    # directory, including all files and subdirectories. Files will not be mirrored
    # if they are identical already (checked via FileUtils#identical?).
    #
    # Copyright (c) 2008 James Adam (The MIT License)

    # added: do mirroring with backup saving turned on
    def self.mirror_with_backup(source, destination)
      self.mirror_files(source, destination, true)
    end

    def self.mirror_files(source, destination, create_backups = false)
      # TODO: use Rake::FileList#pathmap?
      if File.directory?(source)
        source_files  = Dir[source + "/**/*"]
        source_dirs   = source_files.select { |d| File.directory?(d) }
        source_files -= source_dirs
      elsif File.exist? source
        source_dirs   = []
        source_files  = [source]
        source        = File.dirname source
      else
        puts "Could not mirror #{source} - entity does not exist"
        return
      end

      unless source_files.empty?
        base_target_dir = File.join(destination)
        base_target_dir = File.dirname base_target_dir unless File.directory? base_target_dir
        FileUtils.mkdir_p(base_target_dir)
      end

      base_target_dir ||= File.join(destination)

      source_dirs.each do |dir|
        # strip down these paths so we have simple, relative paths we can
        # add to the destination
        target_dir = File.join(base_target_dir, dir.gsub(source, ''))
        begin
          FileUtils.mkdir_p(target_dir)
        rescue Exception => e
          raise "Could not create directory #{target_dir}: \n" + e
        end
      end

      source_files.each do |file|
        begin
          target = File.join(base_target_dir, file.gsub(source, ''))
          unless File.exist?(target) && self.same_contents(file, target)
            # WAS FileUtils.identical?(file, target), but we want to test contents too
            if create_backups && File.exist?(target)
              File.rename(target, target + '~')
            end
            FileUtils.cp(file, target)
          end
        rescue Exception => e
          raise "Could not copy #{file} to #{target}: \n" + e
        end
      end
    end

    # for windows users...
    def self.same_contents(source,destination)
      File.read(source) == File.read(destination)
    end

  end
end

