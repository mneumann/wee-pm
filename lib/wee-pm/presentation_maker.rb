require 'wee-pm/presentation'
require 'wee-pm/converter'

class PresentationMaker < Wee::Component

  AREA_COLS = 90
  DEFAULT_CONVERTER = HtmlConverter

  def initialize(filename)
    super()
    @filename = filename
    @presentation = 
    if File.exists? @filename
      Presentation.from_string(File.read(@filename))
    else
      Presentation.new
    end

    if @presentation.slides.empty?
      @presentation.slides << Slide.new
    end

    @presentation.slides.each do |sl|
      sl.converter = DEFAULT_CONVERTER 
    end

    @edit_mode = false

    @show_title_page = true
  end


  # --------------------------------------------------------------------------
  # Actions: Show
  # --------------------------------------------------------------------------

  def show_title_page
    @show_title_page = true
    @current_slide_index = @current_slide = @current_overlay = nil
  end

  def select_slide(index)
    @show_title_page = false

    @current_slide_index = index
    @current_slide = @presentation.slides[@current_slide_index]
    @current_overlay = 0
  end

  def show_all_overlays
    @current_overlay = @current_slide.number_of_overlays
  end

  def next_slide_or_overlay
    if @show_title_page
      @show_title_page = false
      select_slide(0)
    elsif @current_overlay >= @current_slide.number_of_overlays
      if @current_slide_index < @presentation.slides.size-1
        select_slide(@current_slide_index + 1)
      else
        # TODO: show End-Box
      end
    else
      @current_overlay += 1
    end

    unless @step_mode 
      @current_overlay = @current_slide.number_of_overlays
    end
  end

  def prev_slide_or_overlay
    # we are already on the first page -> do nothing!
    return if @show_title_page

    if @step_mode
      @current_overlay -= 1
      return if @current_overlay >= 0
    end

    @current_slide_index -= 1
    if @current_slide_index < 0
      show_title_page()
    else
      select_slide(@current_slide_index)
      @current_overlay = @current_slide.number_of_overlays 
    end
  end

  # --------------------------------------------------------------------------
  # Actions: Edit
  # --------------------------------------------------------------------------

  def add_new_slide_before
    index = @current_slide_index
    @presentation.slides[index,0] = Slide.new {|s| 
      s.title = @current_slide.title
      s.converter = DEFAULT_CONVERTER
    }
    select_slide(index)
  end

  def add_new_slide_after
    @current_slide_index += 1
    add_new_slide_before
  end

  def delete_current_slide
    return if @presentation.slides.size <= 1
    @presentation.slides.delete_at(@current_slide_index)
    select_slide([@current_slide_index, @presentation.slides.size-1].min)
  end

  def move_current_slide_up
    sl = @presentation.slides
    ci = @current_slide_index
    return if ci <= 0
    sl[ci-1], sl[ci] = sl[ci], sl[ci-1]
    select_slide(ci-1)
  end

  def move_current_slide_down
    sl = @presentation.slides
    ci = @current_slide_index
    return if ci >= sl.size-1
    sl[ci+1], sl[ci] = sl[ci], sl[ci+1]
    select_slide(ci+1)
  end

  def save_presentation
    @presentation.save(@filename)
  end

  def toggle_mode
    @edit_mode = !@edit_mode
  end

  def toggle_step_mode
    @step_mode = !@step_mode
  end

  # --------------------------------------------------------------------------
  # Rendering
  # --------------------------------------------------------------------------

  def render
    r.html do
      r.head do
        r.title("Presentation Maker #{ @filename }")
        r.style(@presentation.style)
        if @current_slide
          r.style(@current_slide.style)
        end
      end

      body = r.body

      #if not @edit_mode
      #  body.onclick(javascript_action {||next_slide_or_overlay})
      #end

      body.with do

        if not @edit_mode
          page_down = r.url_for_callback(proc {
            next_slide_or_overlay()
          })
          page_up = r.url_for_callback(proc {
            prev_slide_or_overlay()
          })
          toggle_mode_url = r.url_for_callback(proc {
            toggle_mode()
          })
          toggle_step_mode_url = r.url_for_callback(proc {
            toggle_step_mode()
          })

          r << %{
            <script>
            document.onkeypress = function(ev) {
              switch (ev.keyCode) {
              case 101: /* 'e' */
                document.location.href='#{ toggle_mode_url }';
                return false;
              case 115: /* 's' */
                document.location.href='#{ toggle_step_mode_url }';
                return false;
              case 34: /* page down */
                document.location.href='#{ page_down }';
                return false;
              case 33: /* page up */
                document.location.href='#{ page_up }';
                return false;
              };
              return true;
            };
            </script>
          }
        end

        r.span.id("navibutton").with do 
          r.anchor.callback { toggle_mode }.with do
            r.space(2)
          end
        end
        render_body
      end
    end
  end

  def render_slide
    if @show_title_page
      r.div.id('titlepage').css_class('slide').with do
        r.h1.onclick(javascript_action {||next_slide_or_overlay}).
          with(@presentation.title)

        r.div.id('author_email').with do
          r.text @presentation.author
          r.text(" (")
          r.anchor.href("mailto:#{ @presentation.email }").with(@presentation.email)
          r.text(")")
        end

      end
    elsif @current_slide
      r.div.id('slides').css_class('slide').  with do
        r.h1.onclick(javascript_action {||next_slide_or_overlay}).
          with(@current_slide.title)
        @current_slide.render_on(r, @current_overlay) 
      end
    end
  end

  def render_navi
    r.div.id('naviframe').with do
      r.anchor.callback{toggle_mode}.with { r.text('Hide') }

      r.text(" | ")

      r.anchor.callback { toggle_step_mode }.with do
        r.text('Change into Full-Slide mode') if @step_mode
        r.text('Change into Step mode') if !@step_mode
      end

      r.text(" | ")
      r.anchor.callback{save_presentation}.with { r.text('Save presentation') }
      r.hr

      r.text("Presentation: ")
      if @show_title_page
        r.text(@presentation.title)
      else
        r.anchor.callback{show_title_page}.with { r.text(@presentation.title) }
      end
      r.break

      render_outline

      r.hr

      if @show_title_page
        render_title_edit
      else
        render_slide_edit
      end
    end
  end

  def render_title_edit
    r.form do
      r.submit_button.value('Update')

      r.table.with do
        %w(title author email).each do |f| 
          r.table_row.with do
            r.table_data("#{ f.capitalize }: ")
            r.table_data.with {
              r.text_input.size(35).
                callback {|c| @presentation.send("#{ f }=", c.to_s) }.
                value(@presentation.send("#{ f }"))
            }
          end
        end
     end # table

     r.paragraph
     r.text("Style:")
     r.break
     r.text_area.cols(AREA_COLS).rows(10).callback {|c| @presentation.style = c.to_s}.
       with(@presentation.style)

    end
  end

  def render_slide_edit
    r.ul do 
      r.li {
        r.text('Add new slide ')
        r.anchor.callback{add_new_slide_before}.with { r.text('before') }; r.text(' / ')
        r.anchor.callback{add_new_slide_after}.with { r.text('after') }; r.space
        r.text('current')
      }
      r.li {
        r.text('Current slide: ')
        r.anchor.callback{move_current_slide_up}.with { r.text('move up') }; r.text(' / ')
        r.anchor.callback{move_current_slide_down}.with { r.text('move down') }; r.text(' / ')
        r.anchor.callback{delete_current_slide}.with { r.text('delete') }
      }
    end

    r.hr

    r.paragraph
    r.form do
      r.submit_button.value('Update').callback { @current_overlay = @current_slide.number_of_overlays }
      r.space

      r.text "Title: "
      r.text_input.size(35).callback {|c| @current_slide.title = c.to_s}.value(@current_slide.title)

      r.paragraph
      r.text_area.cols(AREA_COLS).rows(30).callback {|c| @current_slide.content = c.to_s}.with(@current_slide.content)

      r.paragraph
      r.text "Annotations:"
      r.break
      r.text_area.cols(AREA_COLS).rows(10).callback {|c| @current_slide.annotations = c.to_s}.
        with(@current_slide.annotations)

      r.paragraph
      r.text "Style:"
      r.break
      r.text_area.cols(AREA_COLS).rows(10).callback {|c| @current_slide.style = c.to_s}.
        with(@current_slide.style)

    end
  end

  def render_outline
    r.ol {
      @presentation.slides.each_with_index do |slide, i|
        r.li do
          if i == @current_slide_index
            r.bold slide.title
            r.break

            (0 .. @current_slide.number_of_overlays).each do |j|
              if j == @current_overlay
                r.text "#{ j+1 }"
              else
                r.anchor.callback { @current_overlay = j }.with {
                  r.text "#{ j+1 }"
                }
              end
              r.space
            end
          else
            r.anchor.callback { select_slide(i); show_all_overlays() }.with {
              r.text slide.title
            }
          end
        end
      end
    }
  end

  def render_body
    if not @edit_mode
      render_slide
    else
      r.table do
        r.table_row do

          r.table_data.valign('top').with do 
            render_navi
          end

          r.table_data.valign('top').with do
            render_slide
          end

        end
      end
    end
  end

  private

  def javascript_action(&block)
    url = r.url_for_callback(block)
    "javascript: document.location.href='#{ url }';"
  end

end
