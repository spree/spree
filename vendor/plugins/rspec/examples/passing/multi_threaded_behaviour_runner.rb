class MultiThreadedExampleGroupRunner < Spec::Runner::ExampleGroupRunner
  def initialize(options, arg)
    super(options)
    # configure these
    @thread_count = 4
    @thread_wait = 0
  end

  def run
    @threads = []
    q = Queue.new
    example_groups.each { |b| q << b}
    success = true
    @thread_count.times do
      @threads << Thread.new(q) do |queue|
        while not queue.empty?
          example_group = queue.pop
          success &= example_group.suite.run(nil)
        end
      end
      sleep @thread_wait
    end
    @threads.each {|t| t.join}
    success
  end
end

MultiThreadedBehaviourRunner = MultiThreadedExampleGroupRunner