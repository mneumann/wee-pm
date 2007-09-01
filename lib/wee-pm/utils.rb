require 'enumerator'

def remove_leading_and_trailing_empty_lines(str)
  remove_trailing_empty_lines(remove_leading_empty_lines(str))
end

def remove_trailing_empty_lines(str)
  str = str.chomp + "\n"
  str = remove_leading_empty_lines(str.to_enum(:each_line).to_a.reverse.join(""))
  str.to_enum(:each_line).to_a.reverse.join("")
end

def remove_leading_empty_lines(str)
  first_non_empty_line_seen = false
  res = ""
  str.each_line {|l|
    if first_non_empty_line_seen
      res << l
    else
      unless l.strip.empty?
        first_non_empty_line_seen = true
        res << l
      end
    end
  }
  res
end

if __FILE__ == $0
  require 'test/unit'

  class TC < Test::Unit::TestCase
    def test_leading_trailing
      str = "   \n   \n   test   \n   \n"
      r = remove_leading_and_trailing_empty_lines(str)
      assert_equal "   test   \n", r
    end
  end

end
