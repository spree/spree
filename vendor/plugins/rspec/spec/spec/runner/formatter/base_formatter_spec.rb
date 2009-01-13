require File.dirname(__FILE__) + "/../../../spec_helper"

module Spec
  module Runner
    module Formatter
      describe BaseFormatter do
        subject {BaseFormatter.new(nil, nil)}
        
        it {should respond_to(:start            ).with(1).argument }
        it {should respond_to(:add_example_group).with(1).argument }
        it {should respond_to(:example_passed   ).with(1).argument }
        it {should respond_to(:example_started  ).with(1).argument }
        it {should respond_to(:example_failed   ).with(3).arguments}
        it {should respond_to(:example_pending  ).with(3).arguments}
        it {should respond_to(:start_dump       ).with(0).arguments}
        it {should respond_to(:dump_failure     ).with(2).arguments}
        it {should respond_to(:dump_summary     ).with(4).arguments}
        it {should respond_to(:dump_pending     ).with(0).arguments}
        it {should respond_to(:close            ).with(0).arguments}
      end
    end
  end
end
