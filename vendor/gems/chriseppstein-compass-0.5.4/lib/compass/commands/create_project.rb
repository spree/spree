require 'fileutils'
require File.join(File.dirname(__FILE__), 'base')
require File.join(File.dirname(__FILE__), 'update_project')
require File.join(Compass.lib_directory, 'compass', 'installers')

module Compass
  module Commands
    class CreateProject < ProjectBase

      include Compass::Installers

      attr_accessor :installer

      def initialize(working_path, options)
        super(working_path, options)
        installer_args = [project_template_directory, project_directory, self.options]
        @installer = case options[:project_type]
        when :stand_alone
          StandAloneInstaller.new *installer_args
        when :rails
          RailsInstaller.new *installer_args
        else
          raise "Unknown project type: #{project_type}"
        end
      end
      
      # all commands must implement perform
      def perform
        installer.init
        installer.run(:skip_finalization => true)
        UpdateProject.new(working_path, options).perform if installer.compilation_required?
        installer.finalize(:create => true)
      end

      def project_template_directory
        File.join(framework.templates_directory, "project")
      end

    end
  end
end