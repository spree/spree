namespace :test do
  desc "List the names of the test methods in a specification like format"
  task :list do

    require 'test/unit'
    require 'rubygems'
    require 'active_support'

    # bug in test unit.  Set to true to stop from running.
    Test::Unit.run = true

    test_files = Dir.glob(File.join('test', '**', '*_test.rb'))
    test_files.each do |file|
      load file
      klass = File.basename(file, '.rb').classify.constantize
      
      puts
      puts "#{klass.name.gsub(/Test$/, '')}"
      test_methods = klass.instance_methods.grep(/^test/).map {|s| s.gsub(/^test: /, '')}.sort
      test_methods.each {|m| puts "  - #{m}" }
      # puts "#{klass.name.gsub(/Test$/, '')}"
      # test_methods = klass.instance_methods.grep(/^test/).sort
      # 
      # method_hash = test_methods.inject({}) do |h, name|
      #   header = name.gsub(/^test: (.*)should.*$/, '\1')
      #   test   = name.gsub(/^test:.*should (.*)$/, '\1')
      #   h[header] ||= []
      #   h[header] << test
      #   h
      # end
      # 
      # method_hash.keys.sort.each do |header|
      #   puts "  #{header.chomp} should"
      #   method_hash[header].each do |test|
      #     puts "    - #{test}"
      #   end
      # end
    end
  end
end
