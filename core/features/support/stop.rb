After do |scenario|
  if scenario.failed? and scenario.source_tag_names.include?("@wip") and
     scenario.source_tag_names.include?("@stop")
    puts "Scenario failed. We're in @wip mode, so I've stopped here. You can inspect the issue and leave the console after that."
    require 'irb'
    require 'irb/completion'
    ARGV.clear
    IRB.start
  end
end
