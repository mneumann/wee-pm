require 'rdoc/markup/simple_markup'
require 'rdoc/markup/simple_markup/to_html'

class ExtendedHtml < SM::ToHtml
  # We're invoked with a potential external hyperlink.
  # [mailto:]   just gets inserted.
  # [http:]     links are checked to see if they
  #             reference an image. If so, that image gets inserted
  #             using an <img> tag. Otherwise a conventional <a href>
  #             is used.

  attr_accessor :block_processor
  
  def handle_special_HYPERLINK(special)
    url = special.text
    if url =~ /([A-Za-z]+):(.*)/
      type = $1
      path = $2
    else
      # www.
      type = "http"
      path = url
      url  = "http://#{url}"
    end

    img_attrs = {}
    if type == "http" &&  url =~ /\.(gif|png|jpg|jpeg|bmp)((;.*)?)$/   #((;\w+[=][^;]*)*)
      if $2.nil? or $2.empty?
        attr_size = 0
      else
        attr_size = $~.offset(2)[1] - $~.offset(2)[0]
        m = $2.to_s[1..-1]
        m.split(";").each {|a| 
          k, v = a.split("=", 2)
          img_attrs[k] = v
        }
      end

      s = img_attrs.keys.grep(/^\d+x\d+$/)
      width, height = s.first.split("x", 2) if s.size == 1
      width = img_attrs['w'] || img_attrs['width'] || width
      height = img_attrs['h'] || img_attrs['height'] || height

      attrs = ""
      attrs << 'width="' + width + '" ' if width 
      attrs << 'height="' + height + '" ' if height 
      attrs << 'style="float: left;padding-right: 40px;" ' if img_attrs['floating'] == 'left'

      src = 
      if path[0,2] == "./"
        path[2..(-1-attr_size)]
      elsif path[0,2] == "//"
        "http:" + path[0..(-1-attr_size)]
      else
        "http://" + path[0..(-1-attr_size)]
      end
      %{<a href="#{src}"><img src="#{src}" #{ attrs } border="0"></a>}
    else
      "<a href=\"#{url}\">#{url.sub(%r{^\w+:/*}, '')}</a>"
    end
  end

  def handle_special_RUBYTALK(special)
    if special.text =~ /^ruby-talk:(\d+)$/
      num = $1.to_i
      %(<a href="http://rubytalk.com/cgi-bin/scat.rb/ruby/ruby-talk/#{ num }">ruby-talk:#{ num }</a>)
    else
      raise
    end
  end

  # Here's a hypedlink where the label is different to the URL
  #  <label>[url]
  #
  
  def handle_special_TIDYLINK(special)
    text = special.text
    unless text =~ /\{(.*?)\}\[(.*?)\]/ or text =~ /(\S+)\[(.*?)\]/ 
      return text
    end
    label = $1
    url   = $2
    
    if url !~ /\w+?:/ 
      if url =~ /\./
        url = "http://#{url}"
        #else
        #return find_wiki_word(url, label)
      end
    end
    
    "<a href=\"#{url}\">#{label}</a>"
  end

  def accept_verbatim(am, fragment)
    lines = fragment.txt.split("\n")

    # remove leading whitespace
    margin = if lines.first =~ /^(\s+)/ then $1.size else 0 end
    if lines.all? {|l| l[0, margin].strip.empty? }
      lines.map!{|l| l[margin..-1]}
    end

    first_line = lines.first.strip

    case first_line
    when  /^\!\!([^:]*)(:(.*))?$/
      processor, option = $1, $3
      @res << @block_processor.call(processor, option, lines[1..-1].join("\n"))
    else
      @res << annotate("<pre>")
      output = CGI.escapeHTML(lines.join("\n"))

      # strip whitespaces on the right
      if pos = (output =~ /\s*\z/)
        output = output[0,pos] 
      end

      @res << output
      @res << annotate("</pre>") << "\n"
    end
  end

end

class ExtendedMarkup < SM::SimpleMarkup
  def initialize
    super
    # and links of the form  <text>[<url>] or {text with spaces}[<url>]
    add_special(/(((\{.*?\})|\b\S+?)\[\S+?\])/, :TIDYLINK)

    # and external references
    add_special(/((link:|http:|mailto:|ftp:|www\.)\S+\w\/?)/, :HYPERLINK)

    add_special(/(ruby-talk:\d+)/, :RUBYTALK)
  end
end

class SlidesHtml < ExtendedHtml
  attr_accessor :show_number_of_overlays
  attr_accessor :count

  def start_accepting
    super
    @overlays_shown = 0
    @nesting = 0  
    @done = false
  end

  def end_accepting
    if @count
      @overlays_shown
    else
      super
    end
  end

  def accept_paragraph(am, fragment)
    return if @done; overlay_added
    return if @count
    super
  end

  def accept_verbatim(am, fragment)
    return if @done; overlay_added
    return if @count
    super
  end

  def accept_rule(am, fragment)
    return if @done; overlay_added
    super
  end

  def accept_list_start(am, fragment)
    return if @done; @nesting += 1
    super
  end

  def accept_list_end(am, fragment)
    return if @done and @nesting == 0; @nesting -= 1
    super
  end

  def accept_list_item(am, fragment)
    return if @done; overlay_added
    super
  end

  def accept_heading(am, fragment)
    return if @done; overlay_added
    super
  end

  private 

  def overlay_added
    @overlays_shown += 1
    return if @show_number_of_overlays.nil?
    @done = true if @overlays_shown >= @show_number_of_overlays
  end
end

class SlidesMarkup < ExtendedMarkup; end
