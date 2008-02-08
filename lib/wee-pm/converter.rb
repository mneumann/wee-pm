require 'wee-pm/colorize_filter'
require 'tempfile'
 
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

      case processor
      when 'colorize', 'exec'
        send('handle_' + processor, port, option || '', lines)
      else
        raise "unknown processor"
      end
      port
    }
    conv
  end

  def handle_colorize(port, option, lines)
    lang, opts = option.split(",", 2) 
    h = parse_options(opts||'')
    modify_options(h)
    lines = File.read(h['file']) if h['file']

    if h.include?('link') and h['file']
      port << %[<a class="codelink" href="#{ h['file'] }">#{ h['file'] }</a> ]
    end

    if h['exec']
      h['xterm'] = true
      cmd = gen_exec_file(h, h['exec'])

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
  end

  def handle_exec(port, option, lines)
    h = parse_options(option)
    cmd = gen_exec_file(h, lines) 
    url = @r.url_for_callback(proc { spawn cmd })

    port << %[<a class="codelink" href="#{ url }">execute</a>]
    unless h.include?('hidden')
      port << "<pre class='codefile'>"
      port << lines
      port << "</pre>\n"
    end
  end

  def modify_options(h)
    # DUMMY
  end

  def parse_options(options)
    h = {}
    options.split(",").map {|i| k, v = i.split("="); h[k] = v}
    return h
  end

  def gen_exec_file(h, code)
    f = Tempfile.new('pm')
    f << "#!/bin/sh\n"
    f << "cd #{h['cd']}\n" if h['cd']
    f << code
    f << "\nread line\n" if h.include?('xterm')
    f << "rm #{f.path}"
    f.close(false)
    File.chmod(0755, f.path)
    cmd = if h.include?('xterm') then "xterm" else "sh" end
    cmd << " #{f.path}"
    return cmd
  end

  def spawn(exec)
    fork { `#{exec}` }
  end

end

class PsHtmlConverter < HtmlConverter

  private

  def modify_options(h)
    h['exec'] = false
  end

  def handle_exec(port, option, lines)
    port << "<pre class='codefile'>"
    #port << "!!exec#{ option.empty? ? '' : ':' + option }\n" 
    port << lines
    port << "</pre>\n"
  end

end
