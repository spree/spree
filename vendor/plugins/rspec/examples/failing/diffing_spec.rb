describe "Running specs with --diff" do
  it "should print diff of different strings" do
    uk = <<-EOF
RSpec is a
behaviour driven development
framework for Ruby
EOF
    usa = <<-EOF
RSpec is a
behavior driven development
framework for Ruby
EOF
    usa.should == uk
  end

  class Animal
    def initialize(name,species)
      @name,@species = name,species
    end

    def inspect
      <<-EOA
<Animal
name=#{@name},
species=#{@species}
>
      EOA
    end
  end

  it "should print diff of different objects' pretty representation" do
    expected = Animal.new "bob", "giraffe"
    actual   = Animal.new "bob", "tortoise"
    expected.should eql(actual)
  end
end
