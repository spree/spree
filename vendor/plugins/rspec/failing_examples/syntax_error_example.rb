describe "when passing a block to a matcher" do
  it "you should use {} instead of do/end" do
    Object.new.should satisfy do
      "this block is being passed to #should instead of #satisfy - use {} instead"
    end
  end
end
