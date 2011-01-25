Then /^async (?:|I )should see "([^"]*)"(?: within "([^"]*)")?$/ do |text, selector|
  wait_until { page.evaluate_script("jQuery.active === 0") }
  with_scope(selector) do
    if page.respond_to? :should
      page.should have_content(text)
    else
      assert page.has_content?(text)
    end
  end
end

