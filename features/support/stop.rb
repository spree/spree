After do |scenario|
  unless ENV['CI']
    if scenario.failed? && scenario.source_tag_names.include?("@wip") && scenario.source_tag_names.include?("@stop")
      puts "Scenario failed. We're in @wip mode, so I've stopped here." <<
      "You can inspect the issue and leave the console after that."
      require 'irb'
      require 'irb/completion'
      ARGV.clear
      IRB.start
    end
  end
end
