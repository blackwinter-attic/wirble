require 'ostruct'

#
# Wirble: A collection of useful Irb features.
#
# To use, add the following to your ~/.irbrc:
#
#   require 'rubygems'
#   require 'wirble'
#   Wirble.init
#
# If you want color in Irb, add this to your ~/.irbrc as well:
#
#   Wirble.colorize
#
# Note:  I spent a fair amount of time documenting this code in the
# README.  If you've installed via RubyGems, root around your cache a
# little bit (or fire up gem_server) and read it before you tear your
# hair out sifting through the code below.
# 
module Wirble
  VERSION = '0.1.3.2'

  #
  # Load internal Ruby features, including pp, tab-completion, 
  # and a simple prompt.
  #
  module Internals
    # list of internal libraries to automatically load
    LIBRARIES = %w{pp irb/completion}

    #
    # load libraries
    #
    def self.init_libraries
      LIBRARIES.each do |lib| 
        begin
          require lib 
        rescue LoadError
          nil
        end
      end
    end

    #
    # Set a simple prompt, unless a custom one has been specified.
    #
    def self.init_prompt
      # set the prompt
      if IRB.conf[:PROMPT_MODE] == :DEFAULT
        IRB.conf[:PROMPT_MODE] = :SIMPLE
      end
    end

    #
    # Load all Ruby internal features.
    #
    def self.init(opt = nil)
      init_libraries unless opt && opt[:skip_libraries]
      init_prompt unless opt && opt[:skip_prompt]
    end
  end

  #
  # Basic IRB history support.  This is based on the tips from 
  # http://wiki.rubygarden.org/Ruby/page/show/Irb/TipsAndTricks
  #
  class History
    DEFAULTS = {
      :history_path   => ENV['IRB_HISTORY_FILE'] || "~/.irb_history",
      :history_size   => (ENV['IRB_HISTORY_SIZE'] || 1000).to_i,
      :history_perms  => File::WRONLY | File::CREAT | File::TRUNC,
      :history_uniq   => true,
    }
 
    private

    def say(*args)
      puts(*args) if @verbose
    end

    def cfg(key)
      @opt["history_#{key}".intern]
    end

    def save_history
      path, max_size, perms, uniq = %w{path size perms uniq}.map { |v| cfg(v) }

      # read lines from history, and truncate the list (if necessary)
      lines = Readline::HISTORY.to_a

      lines.reverse! if reverse = uniq.to_s == 'reverse'
      lines.uniq!    if uniq
      lines.reverse! if reverse

      lines.slice!(0, lines.size - max_size) if lines.size > max_size

      # write the history file
      real_path = File.expand_path(path)
      File.open(real_path, perms) { |fh| fh.puts lines }
      say 'Saved %d lines to history file %s.' % [lines.size, path]
    end

    def load_history
      # expand history file and make sure it exists
      real_path = File.expand_path(cfg('path'))
      unless File.exist?(real_path)
        say "History file #{real_path} doesn't exist."
        return
      end

      # read lines from file and add them to history
      lines = File.readlines(real_path).map { |line| line.chomp }
      Readline::HISTORY.push(*lines)

      say 'Read %d lines from history file %s' % [lines.size, cfg('path')]
    end

    public

    def initialize(opt = nil)
      @opt = DEFAULTS.merge(opt || {})
      return unless defined? Readline::HISTORY
      load_history
      Kernel.at_exit { save_history }
    end
  end

  #
  # Add color support to IRB.
  #
  module Colorize
    #
    # Tokenize an inspection string.
    #
    module Tokenizer
      def self.tokenize(str)
        raise 'missing block' unless block_given?
        chars = str.split(//)

        # $stderr.puts "DEBUG: chars = #{chars.join(',')}"

        state, val, i, lc = [], '', 0, nil
        while i <= chars.size
          repeat = false
          c = chars[i]

          # $stderr.puts "DEBUG: state = #{state}"

          case state[-1]
          when nil
            case c
            when ':'
              state << :symbol
            when '"'
              state << :string
            when '#'
              state << :object
            when /[a-z]/i
              state << :keyword
              repeat = true
            when /[0-9-]/
              state << :number
              repeat = true
            when '{'
              yield :open_hash, '{'
            when '['
              yield :open_array, '['
            when ']'
              yield :close_array, ']'
            when '}'
              yield :close_hash, '}'
            when /\s/
              yield :whitespace, c
            when ','
              yield :comma, ','
            when '>'
              yield :refers, '=>' if lc == '='
            when '.'
              yield :range, '..' if lc == '.'
            when '='
              # ignore these, they're used elsewhere
              nil
            else 
              # $stderr.puts "DEBUG: ignoring char #{c}"
            end
          when :symbol
            case c
            # XXX: should have =, but that messes up foo=>bar
            when /[a-z0-9_!?]/
              val << c
            else
              yield :symbol_prefix, ':'
              yield state[-1], val
              state.pop; val = ''
              repeat = true
            end
          when :string
            case c
            when '"'
              if lc == "\\"
                val[-1] = ?"
              else
                yield :open_string, '"'
                yield state[-1], val
                state.pop; val = ''
                yield :close_string, '"'
              end
            else
              val << c
            end
          when :keyword
            case c
            when /[a-z0-9_]/i
              val << c
            else
              # is this a class?
              st = val =~ /^[A-Z]/ ? :class : state[-1]

              yield st, val
              state.pop; val = ''
              repeat = true
            end
          when :number
            case c
            when /[0-9e-]/
              val << c
            when '.'
              if lc == '.'
                val[/\.$/] = ''
                yield state[-1], val
                state.pop; val = ''
                yield :range, '..'
              else
                val << c
              end
            else
              yield state[-1], val
              state.pop; val = ''
              repeat = true
            end
          when :object
            case c
            when '<' 
              yield :open_object, '#<'
              state << :object_class
            when ':' 
              state << :object_addr
            when '@' 
              state << :object_line
            when '>'
              yield :close_object, '>'
              state.pop; val = ''
            end
          when :object_class
            case c
            when ':'
              yield state[-1], val
              state.pop; val = ''
              repeat = true
            else
              val << c
            end
          when :object_addr
            case c
            when '>'
            when '@'
              yield :object_addr_prefix, ':'
              yield state[-1], val
              state.pop; val = ''
              repeat = true
            else
              val << c
            end
          when :object_line
            case c
            when '>'
              yield :object_line_prefix, '@'
              yield state[-1], val
              state.pop; val = ''
              repeat = true
            else
              val << c
            end
          else
            raise "unknown state #{state}"
          end

          unless repeat
            i += 1
            lc = c
          end
        end
      end
    end

    #
    # Terminal escape codes for colors.
    #
    module Color
      COLORS = {
        :nothing      => '0;0',
        :black        => '0;30',
        :red          => '0;31',
        :green        => '0;32',
        :brown        => '0;33',
        :blue         => '0;34',
        :cyan         => '0;36',
        :purple       => '0;35',
        :light_gray   => '0;37',
        :dark_gray    => '1;30',
        :light_red    => '1;31',
        :light_green  => '1;32',
        :yellow       => '1;33',
        :light_blue   => '1;34',
        :light_cyan   => '1;36',
        :light_purple => '1;35',
        :white        => '1;37',
      }
      
      #
      # Return the escape code for a given color.
      #
      def self.escape(key)
        COLORS.key?(key) && "\033[#{COLORS[key]}m"
      end
    end

    #
    # Default Wirble color scheme.
    # 
    DEFAULT_COLORS = {
      # delimiter colors
      :comma              => :blue,
      :refers             => :blue,

      # container colors (hash and array)
      :open_hash          => :green,
      :close_hash         => :green,
      :open_array         => :green,
      :close_array        => :green,

      # object colors
      :open_object        => :light_red,
      :object_class       => :white,
      :object_addr_prefix => :blue,
      :object_line_prefix => :blue,
      :close_object       => :light_red,

      # symbol colors
      :symbol             => :yellow,
      :symbol_prefix      => :yellow,

      # string colors
      :open_string        => :red,
      :string             => :cyan,
      :close_string       => :red,

      # misc colors
      :number             => :cyan,
      :keyword            => :green,
      :class              => :light_green,
      :range              => :red,
    }

    #
    # Fruity testing colors.
    # 
    TESTING_COLORS = {
      :comma            => :red,
      :refers           => :red,
      :open_hash        => :blue,
      :close_hash       => :blue,
      :open_array       => :green,
      :close_array      => :green,
      :open_object      => :light_red,
      :object_class     => :light_green,
      :object_addr      => :purple,
      :object_line      => :light_purple,
      :close_object     => :light_red,
      :symbol           => :yellow,
      :symbol_prefix    => :yellow,
      :number           => :cyan,
      :string           => :cyan,
      :keyword          => :white,
      :range            => :light_blue,
    }

    #
    # Set color map to hash
    # 
    def self.colors=(hash)
      @colors = hash
    end

    #
    # Get current color map
    # 
    def self.colors
      @colors ||= {}.update(DEFAULT_COLORS)
    end

    #
    # Return a string with the given color.
    #
    def self.colorize_string(str, color)
      col, nocol = [color, :nothing].map { |key| Color.escape(key) }
      col ? "#{col}#{str}#{nocol}" : str
    end

    #
    # Colorize the results of inspect
    # 
    def self.colorize(str)
      begin
        ret, nocol = '', Color.escape(:nothing)
        Tokenizer.tokenize(str) do |tok, val|
          # c = Color.escape(colors[tok])
          ret << colorize_string(val, colors[tok])
        end
        ret
      rescue
        # catch any errors from the tokenizer (just in case)
        str
      end
    end

    #
    # Enable colorized IRB results.
    # 
    def self.enable(custom_colors = nil)
      # if there's a better way to do this, I'm all ears.
      ::IRB::Irb.class_eval do
        alias :non_color_output_value  :output_value

        def output_value
          if @context.inspect?
            val = Colorize.colorize(@context.last_value.inspect)
            printf @context.return_format, val
          else
            printf @context.return_format, @context.last_value
          end
        end
      end

      self.colors = custom_colors if custom_colors
    end

    #
    # Disable colorized IRB results.
    # 
    def self.disable
      ::IRB::Irb.class_eval do
        alias :output_value  :non_color_output_value
      end
    end
  end

  #
  # Convenient shortcut methods.
  #
  module Shortcuts
    #
    # Print object methods, sorted by name. (excluding methods that
    # exist in the class Object) .
    #
    def po(o)
      o.methods.sort - Object.methods
    end

    #
    # Print object constants, sorted by name.
    #
    def poc(o)
      o.constants.sort
    end
  end

  #
  # Convenient shortcut for ri
  #
  module RiShortcut
    def self.init
      Kernel.class_eval {
        def ri(arg)
           puts `ri '#{arg}'`
        end
      }

      Module.instance_eval {
         def ri(meth=nil)
           if meth
             if instance_methods(false).include? meth.to_s
               puts `ri #{self}##{meth}`
             else
               super
             end
           else
             puts `ri #{self}`
           end
         end
      }
    end
  end



  #
  # Enable color results.
  #
  def self.colorize(custom_colors = nil)
    Colorize.enable(custom_colors)
  end

  #
  # Load everything except color.
  #
  def self.init(opt = nil)
    # make sure opt isn't nil
    opt ||= {}

    # load internal irb/ruby features
    Internals.init(opt) unless opt && opt[:skip_internals]

    # load the history
    History.new(opt) unless opt && opt[:skip_history]

    # load shortcuts
    unless opt && opt[:skip_shortcuts]
      # load ri shortcuts
      RiShortcut.init

      # include common shortcuts
      Object.class_eval { include Shortcuts }
    end

    colorize(opt[:colors]) if opt && opt[:init_colors]
  end
end

