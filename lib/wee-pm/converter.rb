require 'wee-pm/colorize_filter'

class HtmlConverter
  def count_overlays(content)
    conv = converter()
    conv.count = true
    SlidesMarkup.new.convert(content, conv)
  end

  def render_on(r, overlay, content)
    conv = converter()
    conv.count = false
    conv.show_number_of_overlays = overlay
    if overlay > 0
      @r = r
      r << SlidesMarkup.new.convert(content, conv)
    end
  end

  def render_annotations_on(r, annotations)
    conv = converter()
    conv.count = false
    conv.show_number_of_overlays = nil
    @r = r
    r << SlidesMarkup.new.convert(annotations, conv)
  end


  private

  def converter
    conv = SlidesHtml.new 
    conv.block_processor = proc {|processor, option, lines|
      port = ""
      option ||= ""
      case processor
      when 'colorize'
        lang, *more = option.split(",")
        h = {}
        more.map {|i| k, v = i.split("="); h[k] = v}

        lines = File.read(h['file']) if h['file']

        if h.include?('link') and h['file']
          port << %[<a class="codelink" href="#{ h['file'] }">#{ h['file'] }</a> ]
        end

        if h['exec']
          # TODO: generate executable script in callback.
          require 'tempfile'
          f = Tempfile.new('pm')
          f << "#!/bin/sh\n"
          f << "cd #{h['cd']}\n" if h['cd']
          f << h['exec']
          f << "\nread line\n"
          f << "rm #{f.path}"
          f.close(false)
          File.chmod(0755, f.path)
          cmd = "xterm #{ f.path }"

          url = @r.url_for_callback(proc { spawn cmd })
          port << %[<a class="codelink" href="#{ url }">execute</a>]
        end

        if (h.include?('link') and h['file']) or h['exec']
          port << "<pre class='codefile'>"
        else
          port << "<pre>"
        end

        ColorizeFilter.new.run(lines, port, lang)
        port << "</pre>\n"
      when 'exec'
        more = option.split(",")
        h = {}
        more.map {|i| k, v = i.split("="); h[k] = v}

        require 'tempfile'
        f = Tempfile.new('pm')
        f << "#!/bin/sh\n"
        f << "cd #{h['cd']}\n" if h['cd']
        f << lines
        f << "\nread line\n" if h.include?('xterm')
        f << "rm #{f.path}"
        f.close(false)
        File.chmod(0755, f.path)

        cmd = 
        if h.include?('xterm')
          "xterm"
        else
          "sh"
        end
        cmd << " #{f.path}"

        url = @r.url_for_callback(proc { spawn cmd })
        
        port << %[<a class="codelink" href="#{ url }">execute</a>]
        unless h.include?('hidden') or option == "hidden"
          port << "<pre class='codefile'>"
          port << lines
          port << "</pre>\n"
        end
      else
        raise "unknown processor"
      end
      port
    }
    conv
  end

  def spawn(exec)
    fork { `#{exec}` }
  end

end

class PsHtmlConverter < HtmlConverter

  private

  def converter
    conv = SlidesHtml.new 
    conv.block_processor = proc {|processor, option, lines|
      port = ""
      case processor
      when 'colorize'
        port << "<pre>"
        ColorizeFilter.new.run(lines, port, option)
        port << "</pre>\n"
      when 'exec'
        port << "<pre class='codefile'>"
        port << "!!#{processor}#{ option ? ':' + option : ''}\n" 
        port << lines
        port << "</pre>\n"
      else
        raise "unknown processor"
      end
      port
    }
    conv
  end

end
