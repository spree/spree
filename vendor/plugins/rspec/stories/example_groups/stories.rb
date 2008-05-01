require File.join(File.dirname(__FILE__), *%w[.. helper])

with_steps_for :running_rspec do
  Dir["#{File.dirname(__FILE__)}/*"].each do |file|
    run file if File.file?(file) && !(file =~ /\.rb$/)
  end
end