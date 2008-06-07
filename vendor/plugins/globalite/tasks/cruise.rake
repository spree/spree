desc 'Used for Cruise Control Continuous Integration.  Runs bootstrap --> spec'
task :cruise => :environment do
  Rake::Task["spec"].invoke            rescue got_error = true
end