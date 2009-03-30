require 'rubygems'
require 'sass'
require 'fileutils'
require 'pathname'
require File.join(File.dirname(__FILE__), 'base')
require File.join(File.dirname(__FILE__), 'update_project')

module Compass
  module Commands
    class WatchProject < UpdateProject

      attr_accessor :last_update_time

      def perform
        puts ">>> Compiling all stylesheets."
        super
        self.last_update_time = most_recent_update_time
        puts ">>> Compass is now watching for changes. Press Ctrl-C to Stop."
        loop do
          # TODO: Make this efficient by using filesystem monitoring.
          begin
            sleep 1
          rescue Interrupt
            puts ""
            exit 0
          end
          file, t = should_update?
          if t
            begin
              puts ">>> Change detected to: #{file}"
              super
            rescue StandardError => e
              ::Compass::Exec.report_error(e, options)
            end
            self.last_update_time = t
          end
        end
      end

      def most_recent_update_time
        Dir.glob(separate("#{projectize(Compass.configuration.sass_dir)}/**/*.sass")).map {|sass_file| File.stat(sass_file).mtime}.max
      end

      def should_update?
        t = most_recent_update_time
        if t > last_update_time
          file = Dir.glob(separate("#{projectize(Compass.configuration.sass_dir)}/**/*.sass")).detect {|sass_file| File.stat(sass_file).mtime >= t}
          [file, t]
        end
      end
    end
  end
end