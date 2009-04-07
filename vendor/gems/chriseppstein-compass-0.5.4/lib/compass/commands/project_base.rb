require 'rubygems'
require 'sass'
require 'fileutils'
require 'pathname'
require File.join(File.dirname(__FILE__), 'base')

module Compass
  module Commands
    class ProjectBase < Base
      attr_accessor :project_directory, :project_name, :options

      def initialize(working_path, options = {})
        super(working_path, options)
        self.project_name = determine_project_name(working_path, options)
        Compass.configuration.project_path = determine_project_directory(working_path, options)
      end

      protected

      def projectize(path)
        File.join(project_directory, separate(path))
      end

      def project_directory
        Compass.configuration.project_path
      end

      def project_css_subdirectory
        Compass.configuration.css_dir
      end

      def project_src_subdirectory
        Compass.configuration.sass_dir
      end

      # Read the configuration file for this project
      def read_project_configuration
        if File.exists?(projectize('config.rb'))
          Compass.configuration.parse(projectize('config.rb'))
        elsif File.exists?(projectize('src/config.rb'))
          Compass.configuration.parse(projectize('src/config.rb'))
        end
      end

      def assert_project_directory_exists!
        if File.exists?(project_directory) && !File.directory?(project_directory)
          raise Compass::FilesystemConflict.new("#{project_directory} is not a directory.")
        elsif !File.directory?(project_directory)
          raise Compass::Error.new("#{project_directory} does not exist.")
        end
      end

      private

      def determine_project_name(working_path, options)
        if options[:project_name]
          File.basename(strip_trailing_separator(options[:project_name]))
        else
          File.basename(working_path)
        end
      end

      def determine_project_directory(working_path, options)
        if options[:project_name]
          if absolute_path?(options[:project_name])
            options[:project_name]
          else
            File.join(working_path, options[:project_name])
          end
        else
          working_path
        end
      end

      def absolute_path?(path)
        # This is only going to work on unix, gonna need a better implementation.
        path.index(File::SEPARATOR) == 0
      end

    end
  end
end