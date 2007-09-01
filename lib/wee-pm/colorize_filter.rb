class ColorizeFilter
  def initialize(ruby_bin="ruby", colorize_bin=File.join(File.dirname(__FILE__), "colorize.rb"))
    @ruby_bin, @colorize_bin = ruby_bin, colorize_bin
  end

  def run(lines, port, lang="__auto__", filename="")
    lang ||= '__auto__'

    cmd = "#{ @ruby_bin } #{ @colorize_bin } --cache --terminal=xterm-color --strip-ws --lang=#{ lang }"
    if lines.nil?
      cmd << " " + filename
    end

    IO.popen(cmd, "w+") { |f|
      if lines
        f << lines
        f.close_write
      end
      port << f.read
    }
  end
end
