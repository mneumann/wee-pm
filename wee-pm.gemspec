require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = "wee-pm"
  s.version = "0.1"
  s.summary = "A web-based presentation maker and viewer using Wee"
  s.files = Dir['**/*']
  s.bindir = 'bin'
  s.executables = ['wee-pm', 'wee-pm-pdf']
  s.default_executable = 'wee-pm'
  s.add_dependency('wee', '>= 0.10.0')
  s.requirements << 'vim (for colorizing source code)'
  s.requirements << 'html2ps (for creating Postscript output)'
  s.requirements << 'ps2pdf (for creating PDF output)'

  s.author = "Michael Neumann"
  s.email = "mneumann@ntecs.de"
  s.homepage = "http://rubyforge.org/projects/wee"
  s.rubyforge_project = "wee"
end

if __FILE__ == $0
  Gem::manage_gems
  Gem::Builder.new(spec).build
end
