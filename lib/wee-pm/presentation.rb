require 'wee-pm/slideshtml'
require 'wee-pm/utils'

# A presentation is mainly a collection of slides.

class Presentation
  attr_accessor :title, :author, :email, :style
  attr_reader :slides

  class << self
    def from_string(str)
      positions = [0]
      str.scan(/^=([^=].*)$/) { positions << $~.offset(0).first }
      slides = split_at(str, positions)

      new {|pres|
        pres.title = $1.strip if slides[0] =~ /^title::(.*)$/
        pres.author = $1.strip if slides[0] =~ /^author::(.*)$/
        pres.email = $1.strip if slides[0] =~ /^email::(.*)$/
        pres.style = $1.strip if slides[0] =~ /^style::(.*)^endstyle::$/m

        slides[1..-1].each do |s|
          pres.slides << Slide.from_string(s)
        end
      }
    end

    private

    def split_at(s, pos)
      (0..(pos.size-2)).collect {|i| s[pos[i]...pos[i+1]] } + [s[pos[-1]..-1]]
    end
  end

  def initialize
    @title = 'unnamed presentation'
    @author = ''
    @email = ''
    @style = ''
    @slides = []
    yield self if block_given?
  end

  def to_s
    str = "title:: #{ @title }\n" + 
          "author:: #{ @author }\n" + 
          "email:: #{ @email }\n"
    unless @style.strip.empty?
      str << "style::\n"
      str << @style
      str << "\n"
      str << "endstyle::\n"
    end

    str << "\n"

    @slides.each { |s| str << s.to_s }
    str.gsub!("\r\n", "\n")
    str
  end

  def save(filename)
    File.open(filename, 'w+') {|f| f << self.to_s }
  end
end

# Each slide consists of one or more overlays.
class Slide
  attr_accessor :title
  attr_accessor :content  # the rdoc content of the slide (excluding the title)
  attr_accessor :annotations
  attr_accessor :converter
  attr_accessor :style

  def content=(str)
    @content = remove_leading_and_trailing_empty_lines(str) 
  end

  def annotations=(str)
    @annotations = remove_leading_and_trailing_empty_lines(str) 
  end

  def to_s
    str = "= #{ @title }\n\n" + @content + "\n"
    unless @annotations.strip.empty?
      str << "annotations::\n"
      str << @annotations
      str << "\n"
      str << "endannotations::\n"
    end
    unless @style.strip.empty?
      str << "style::\n"
      str << @style
      str << "\n"
      str << "endstyle::\n"
    end
    str << "\n"
    str
  end

  def self.from_string(str)
    new {|s|
      if str =~ /^=([^=].*)$/
        str = $~.post_match
        s.title = $1.strip
      end
      if str =~ /^\w+::/
        s.content = $~.pre_match
        if str =~ /^annotations::(.*)^endannotations::$/m
          s.annotations = $1.strip
        end
        if str =~ /^style::(.*)^endstyle::$/m
          s.style = $1.strip
        end
      else
        s.content = str
      end
    }
  end

  def initialize
    @number_of_overlays = []
    @title = 'unnamed slide'
    @content = ''
    @annotations = '' 
    @style = ''
    yield self if block_given?
  end

  def number_of_overlays
    if @content != @number_of_overlays[1]
      # content has changed -> re-calculate the number of overlays
      num = 
      if @content.strip.empty? 
        0
      else
        converter().new.count_overlays(@content)
      end
      @number_of_overlays = [num, @content.dup]
    end
    @number_of_overlays[0]
  end

  def render_on(r, overlay) 
    converter().new.render_on(r, overlay, @content)
  end

  def render_annotations_on(r)
    converter().new.render_annotations_on(r, @annotations)
  end

end
