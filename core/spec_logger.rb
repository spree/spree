require 'rspec/core/formatters/progress_formatter'
class SpecLogger < RSpec::Core::Formatters::ProgressFormatter

  def example_started(example)
    super
    File.open("specs.log", "a+") do |f|
      f.write(example.location + "\n")
    end
  end
end
