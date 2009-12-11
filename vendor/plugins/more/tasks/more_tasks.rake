require 'less' if defined? Less::Command
require File.join(File.dirname(__FILE__), '..', 'lib', 'more') if defined? Less::Command

namespace :more do
  desc "Generate CSS files from LESS files"
  task :parse => :environment do
    puts "Parsing files from #{Less::More.source_path}."
    Less::More.parse
    puts "Done."

  end
  
  desc "Remove generated CSS files"
  task :clean => :environment do
    puts "Deleting files.."
    Less::More.clean
    puts "Done."
  end
end