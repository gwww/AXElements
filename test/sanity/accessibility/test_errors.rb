class TestAccessibilityErrors < MiniTest::Unit::TestCase

  def test_lookup_failure_shows_inspect_output_of_arguments
    e = Accessibility::LookupFailure.new(:element, :name)
    def e.backtrace; []; end
    assert_match /:name was not found for :element/, e.message

    o = Object.new
    def o.inspect; '"I am an object"'; end
    e = Accessibility::LookupFailure.new(o, [1,2,3])
    def e.backtrace; []; end
    assert_match /\[1, 2, 3\] was not found for "I am an object"/, e.message
  end

  def test_lookup_failue_is_kind_of_arg_error
    assert_includes Accessibility::LookupFailure.ancestors, ArgumentError
  end

  def test_search_failure_is_kind_of_no_method_error
    assert_includes Accessibility::SearchFailure.ancestors, NoMethodError
  end

end