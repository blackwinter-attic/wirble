require 'rubygems'

spec = Gem::Specification.new do |s|

  #### Basic information.

  s.name = 'wirble'
  s.version = '0.1.3'
  s.summary = <<-EOF
    Handful of common Irb features, made easy.
  EOF
  s.description = <<-EOF
    A handful of useful Irb features, including colorized results,
    tab-completion, history, a simple prompt, and several helper
    methods, all rolled into one easy to use package.
  EOF

  s.requirements << 'Ruby, version 1.8.0 (or newer)'

  # Which files are to be included in this gem?  Everything!  (Except .hg directories.)
  s.files = Dir.glob("**/*").delete_if { |item| item.include?(".hg") }

  # C code extensions.

  s.require_path = '.' # is this correct?

  # Load-time details: library and application (you will need one or both).
  s.autorequire = 'wirble'
  s.has_rdoc = true
  s.rdoc_options = ['--webcvs',
  'http://hg.pablotron.org/wirble', '--title',
  'Wirble API Documentation', 'wirble.rb', 'README', 'ChangeLog',
  'COPYING']

  # Author and project details.
  s.author = 'Paul Duncan'
  s.email = 'pabs@pablotron.org'
  s.homepage = 'http://pablotron.org/software/wirble/'
  s.rubyforge_project = 'wirble'
end
