steps_for :multiline_steps do
  Given "I have a two line step with this text:$text" do |text|
    @text = text
  end

  When "I have a When with the same two lines:$text" do |text|
    text.should == @text
  end

  Then "it should match:$text" do |text|
    text.should == @text
  end
end