require File.join(File.dirname(__FILE__), 'project_base')

module Compass
  module Commands
    class WriteConfiguration < ProjectBase
      
      def initialize(working_path, options)
        super
        assert_project_directory_exists!
      end

      def perform
        read_project_configuration
        Compass.configuration.set_maybe(options)
        Compass.configuration.set_defaults!
        config_file = projectize("config.rb")
        if File.exists?(config_file)
          if options[:force]
            logger.record(:overwrite, config_file)
          else
            message = "#{config_file} already exists. Run with --force to overwrite."
            raise Compass::FilesystemConflict.new(message)
          end
        else
          logger.record(:create, basename(config_file))
        end
        project_path, Compass.configuration.project_path = Compass.configuration.project_path, nil
        open(config_file,'w') do |config|
          config.puts Compass.configuration.serialize
        end
        Compass.configuration.project_path = project_path
      end


    end
  end
end