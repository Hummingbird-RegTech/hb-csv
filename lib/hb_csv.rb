# encoding: US-ASCII
# frozen_string_literal: true
# = csv.rb -- HBCSV Reading and Writing
#
# Created by James Edward Gray II on 2005-10-31.
#
# See HBCSV for documentation.
#
# == Description
#
# Welcome to the new and improved HBCSV.
#
# This version of the HBCSV library began its life as FasterHBCSV.  FasterHBCSV was
# intended as a replacement to Ruby's then standard HBCSV library.  It was
# designed to address concerns users of that library had and it had three
# primary goals:
#
# 1.  Be significantly faster than HBCSV while remaining a pure Ruby library.
# 2.  Use a smaller and easier to maintain code base.  (FasterHBCSV eventually
#     grew larger, was also but considerably richer in features.  The parsing
#     core remains quite small.)
# 3.  Improve on the HBCSV interface.
#
# Obviously, the last one is subjective.  I did try to defer to the original
# interface whenever I didn't have a compelling reason to change it though, so
# hopefully this won't be too radically different.
#
# We must have met our goals because FasterHBCSV was renamed to HBCSV and replaced
# the original library as of Ruby 1.9. If you are migrating code from 1.8 or
# earlier, you may have to change your code to comply with the new interface.
#
# == What's Different From the Old HBCSV?
#
# I'm sure I'll miss something, but I'll try to mention most of the major
# differences I am aware of, to help others quickly get up to speed:
#
# === HBCSV Parsing
#
# * This parser is m17n aware.  See HBCSV for full details.
# * This library has a stricter parser and will throw MalformedCSVErrors on
#   problematic data.
# * This library has a less liberal idea of a line ending than HBCSV.  What you
#   set as the <tt>:row_sep</tt> is law.  It can auto-detect your line endings
#   though.
# * The old library returned empty lines as <tt>[nil]</tt>.  This library calls
#   them <tt>[]</tt>.
# * This library has a much faster parser.
#
# === Interface
#
# * HBCSV now uses Hash-style parameters to set options.
# * HBCSV no longer has generate_row() or parse_row().
# * The old HBCSV's Reader and Writer classes have been dropped.
# * HBCSV::open() is now more like Ruby's open().
# * HBCSV objects now support most standard IO methods.
# * HBCSV now has a new() method used to wrap objects like String and IO for
#   reading and writing.
# * HBCSV::generate() is different from the old method.
# * HBCSV no longer supports partial reads.  It works line-by-line.
# * HBCSV no longer allows the instance methods to override the separators for
#   performance reasons.  They must be set in the constructor.
#
# If you use this library and find yourself missing any functionality I have
# trimmed, please {let me know}[mailto:james@grayproductions.net].
#
# == Documentation
#
# See HBCSV for documentation.
#
# == What is HBCSV, really?
#
# HBCSV maintains a pretty strict definition of HBCSV taken directly from
# {the RFC}[http://www.ietf.org/rfc/rfc4180.txt].  I relax the rules in only one
# place and that is to make using this library easier.  HBCSV will parse all valid
# HBCSV.
#
# What you don't want to do is feed HBCSV invalid data.  Because of the way the
# HBCSV format works, it's common for a parser to need to read until the end of
# the file to be sure a field is invalid.  This eats a lot of time and memory.
#
# Luckily, when working with invalid HBCSV, Ruby's built-in methods will almost
# always be superior in every way.  For example, parsing non-quoted fields is as
# easy as:
#
#   data.split(",")
#
# == Questions and/or Comments
#
# Feel free to email {James Edward Gray II}[mailto:james@grayproductions.net]
# with any questions.

require "forwardable"
require "English"
require "date"
require "stringio"
require_relative "hb_csv/table"
require_relative "hb_csv/row"

# This provides String#match? and Regexp#match? for Ruby 2.3.
unless String.method_defined?(:match?)
  class HBCSV
    module MatchP
      refine String do
        def match?(pattern)
          self =~ pattern
        end
      end

      refine Regexp do
        def match?(string)
          self =~ string
        end
      end
    end
  end

  using HBCSV::MatchP
end

#
# This class provides a complete interface to HBCSV files and data.  It offers
# tools to enable you to read and write to and from Strings or IO objects, as
# needed.
#
# The most generic interface of a class is:
#
#    csv = HBCSV.new(string_or_io, **options)
#
#    # Reading: IO object should be open for read
#    csv.read # => array of rows
#    # or
#    csv.each do |row|
#      # ...
#    end
#    # or
#    row = csv.shift
#
#    # Writing: IO object should be open for write
#    csv << row
#
# There are several specialized class methods for one-statement reading or writing,
# described in the Specialized Methods section.
#
# If a String passed into ::new, it is internally wrapped into a StringIO object.
#
# +options+ can be used for specifying the particular HBCSV flavor (column
# separators, row separators, value quoting and so on), and for data conversion,
# see Data Conversion section for the description of the latter.
#
# == Specialized Methods
#
# === Reading
#
#   # From a file: all at once
#   arr_of_rows = HBCSV.read("path/to/file.csv", **options)
#   # iterator-style:
#   HBCSV.foreach("path/to/file.csv", **options) do |row|
#     # ...
#   end
#
#   # From a string
#   arr_of_rows = HBCSV.parse("HBCSV,data,String", **options)
#   # or
#   HBCSV.parse("HBCSV,data,String", **options) do |row|
#     # ...
#   end
#
# === Writing
#
#   # To a file
#   HBCSV.open("path/to/file.csv", "wb") do |csv|
#     csv << ["row", "of", "HBCSV", "data"]
#     csv << ["another", "row"]
#     # ...
#   end
#
#   # To a String
#   csv_string = HBCSV.generate do |csv|
#     csv << ["row", "of", "HBCSV", "data"]
#     csv << ["another", "row"]
#     # ...
#   end
#
# === Shortcuts
#
#   # Core extensions for converting one line
#   csv_string = ["HBCSV", "data"].to_csv   # to HBCSV
#   csv_array  = "HBCSV,String".parse_csv   # from HBCSV
#
#   # HBCSV() method
#   HBCSV             { |csv_out| csv_out << %w{my data here} }  # to $stdout
#   HBCSV(csv = "")   { |csv_str| csv_str << %w{my data here} }  # to a String
#   HBCSV($stderr)    { |csv_err| csv_err << %w{my data here} }  # to $stderr
#   HBCSV($stdin)     { |csv_in|  csv_in.each { |row| p row } }  # from $stdin
#
# == Data Conversion
#
# === HBCSV with headers
#
# HBCSV allows to specify column names of HBCSV file, whether they are in data, or
# provided separately. If headers specified, reading methods return an instance
# of HBCSV::Table, consisting of HBCSV::Row.
#
#   # Headers are part of data
#   data = HBCSV.parse(<<~ROWS, headers: true)
#     Name,Department,Salary
#     Bob,Engeneering,1000
#     Jane,Sales,2000
#     John,Management,5000
#   ROWS
#
#   data.class      #=> HBCSV::Table
#   data.first      #=> #<HBCSV::Row "Name":"Bob" "Department":"Engeneering" "Salary":"1000">
#   data.first.to_h #=> {"Name"=>"Bob", "Department"=>"Engeneering", "Salary"=>"1000"}
#
#   # Headers provided by developer
#   data = HBCSV.parse('Bob,Engeneering,1000', headers: %i[name department salary])
#   data.first      #=> #<HBCSV::Row name:"Bob" department:"Engeneering" salary:"1000">
#
# === Typed data reading
#
# HBCSV allows to provide a set of data _converters_ e.g. transformations to try on input
# data. Converter could be a symbol from HBCSV::Converters constant's keys, or lambda.
#
#   # Without any converters:
#   HBCSV.parse('Bob,2018-03-01,100')
#   #=> [["Bob", "2018-03-01", "100"]]
#
#   # With built-in converters:
#   HBCSV.parse('Bob,2018-03-01,100', converters: %i[numeric date])
#   #=> [["Bob", #<Date: 2018-03-01>, 100]]
#
#   # With custom converters:
#   HBCSV.parse('Bob,2018-03-01,100', converters: [->(v) { Time.parse(v) rescue v }])
#   #=> [["Bob", 2018-03-01 00:00:00 +0200, "100"]]
#
# == HBCSV and Character Encodings (M17n or Multilingualization)
#
# This new HBCSV parser is m17n savvy.  The parser works in the Encoding of the IO
# or String object being read from or written to.  Your data is never transcoded
# (unless you ask Ruby to transcode it for you) and will literally be parsed in
# the Encoding it is in.  Thus HBCSV will return Arrays or Rows of Strings in the
# Encoding of your data.  This is accomplished by transcoding the parser itself
# into your Encoding.
#
# Some transcoding must take place, of course, to accomplish this multiencoding
# support.  For example, <tt>:col_sep</tt>, <tt>:row_sep</tt>, and
# <tt>:quote_char</tt> must be transcoded to match your data.  Hopefully this
# makes the entire process feel transparent, since HBCSV's defaults should just
# magically work for your data.  However, you can set these values manually in
# the target Encoding to avoid the translation.
#
# It's also important to note that while all of HBCSV's core parser is now
# Encoding agnostic, some features are not.  For example, the built-in
# converters will try to transcode data to UTF-8 before making conversions.
# Again, you can provide custom converters that are aware of your Encodings to
# avoid this translation.  It's just too hard for me to support native
# conversions in all of Ruby's Encodings.
#
# Anyway, the practical side of this is simple:  make sure IO and String objects
# passed into HBCSV have the proper Encoding set and everything should just work.
# HBCSV methods that allow you to open IO objects (HBCSV::foreach(), HBCSV::open(),
# HBCSV::read(), and HBCSV::readlines()) do allow you to specify the Encoding.
#
# One minor exception comes when generating HBCSV into a String with an Encoding
# that is not ASCII compatible.  There's no existing data for HBCSV to use to
# prepare itself and thus you will probably need to manually specify the desired
# Encoding for most of those cases.  It will try to guess using the fields in a
# row of output though, when using HBCSV::generate_line() or Array#to_csv().
#
# I try to point out any other Encoding issues in the documentation of methods
# as they come up.
#
# This has been tested to the best of my ability with all non-"dummy" Encodings
# Ruby ships with.  However, it is brave new code and may have some bugs.
# Please feel free to {report}[mailto:james@grayproductions.net] any issues you
# find with it.
#
class HBCSV

  # The error thrown when the parser encounters illegal HBCSV formatting.
  class MalformedCSVError < RuntimeError
    attr_reader :line_number
    alias_method :lineno, :line_number
    def initialize(message, line_number)
      @line_number = line_number
      super("#{message} in line #{line_number}.")
    end
  end

  #
  # A FieldInfo Struct contains details about a field's position in the data
  # source it was read from.  HBCSV will pass this Struct to some blocks that make
  # decisions based on field structure.  See HBCSV.convert_fields() for an
  # example.
  #
  # <b><tt>index</tt></b>::  The zero-based index of the field in its row.
  # <b><tt>line</tt></b>::   The line of the data source this row is from.
  # <b><tt>header</tt></b>:: The header for the column, when available.
  #
  FieldInfo = Struct.new(:index, :line, :header)

  # A Regexp used to find and convert some common Date formats.
  DateMatcher     = / \A(?: (\w+,?\s+)?\w+\s+\d{1,2},?\s+\d{2,4} |
                            \d{4}-\d{2}-\d{2} )\z /x
  # A Regexp used to find and convert some common DateTime formats.
  DateTimeMatcher =
    / \A(?: (\w+,?\s+)?\w+\s+\d{1,2}\s+\d{1,2}:\d{1,2}:\d{1,2},?\s+\d{2,4} |
            \d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2} |
            # ISO-8601
            \d{4}-\d{2}-\d{2}
              (?:T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?(?:[+-]\d{2}(?::\d{2})|Z)?)?)?
        )\z /x

  # The encoding used by all converters.
  ConverterEncoding = Encoding.find("UTF-8")

  #
  # This Hash holds the built-in converters of HBCSV that can be accessed by name.
  # You can select Converters with HBCSV.convert() or through the +options+ Hash
  # passed to HBCSV::new().
  #
  # <b><tt>:integer</tt></b>::    Converts any field Integer() accepts.
  # <b><tt>:float</tt></b>::      Converts any field Float() accepts.
  # <b><tt>:numeric</tt></b>::    A combination of <tt>:integer</tt>
  #                               and <tt>:float</tt>.
  # <b><tt>:date</tt></b>::       Converts any field Date::parse() accepts.
  # <b><tt>:date_time</tt></b>::  Converts any field DateTime::parse() accepts.
  # <b><tt>:all</tt></b>::        All built-in converters.  A combination of
  #                               <tt>:date_time</tt> and <tt>:numeric</tt>.
  #
  # All built-in converters transcode field data to UTF-8 before attempting a
  # conversion.  If your data cannot be transcoded to UTF-8 the conversion will
  # fail and the field will remain unchanged.
  #
  # This Hash is intentionally left unfrozen and users should feel free to add
  # values to it that can be accessed by all HBCSV objects.
  #
  # To add a combo field, the value should be an Array of names.  Combo fields
  # can be nested with other combo fields.
  #
  Converters  = {
    integer:   lambda { |f|
      Integer(f.encode(ConverterEncoding)) rescue f
    },
    float:     lambda { |f|
      Float(f.encode(ConverterEncoding)) rescue f
    },
    numeric:   [:integer, :float],
    date:      lambda { |f|
      begin
        e = f.encode(ConverterEncoding)
        e.match?(DateMatcher) ? Date.parse(e) : f
      rescue  # encoding conversion or date parse errors
        f
      end
    },
    date_time: lambda { |f|
      begin
        e = f.encode(ConverterEncoding)
        e.match?(DateTimeMatcher) ? DateTime.parse(e) : f
      rescue  # encoding conversion or date parse errors
        f
      end
    },
    all:       [:date_time, :numeric],
  }

  #
  # This Hash holds the built-in header converters of HBCSV that can be accessed
  # by name.  You can select HeaderConverters with HBCSV.header_convert() or
  # through the +options+ Hash passed to HBCSV::new().
  #
  # <b><tt>:downcase</tt></b>::  Calls downcase() on the header String.
  # <b><tt>:symbol</tt></b>::    Leading/trailing spaces are dropped, string is
  #                              downcased, remaining spaces are replaced with
  #                              underscores, non-word characters are dropped,
  #                              and finally to_sym() is called.
  #
  # All built-in header converters transcode header data to UTF-8 before
  # attempting a conversion.  If your data cannot be transcoded to UTF-8 the
  # conversion will fail and the header will remain unchanged.
  #
  # This Hash is intentionally left unfrozen and users should feel free to add
  # values to it that can be accessed by all HBCSV objects.
  #
  # To add a combo field, the value should be an Array of names.  Combo fields
  # can be nested with other combo fields.
  #
  HeaderConverters = {
    downcase: lambda { |h| h.encode(ConverterEncoding).downcase },
    symbol:   lambda { |h|
      h.encode(ConverterEncoding).downcase.gsub(/[^\s\w]+/, "").strip.
                                           gsub(/\s+/, "_").to_sym
    }
  }

  #
  # The options used when no overrides are given by calling code.  They are:
  #
  # <b><tt>:col_sep</tt></b>::            <tt>","</tt>
  # <b><tt>:row_sep</tt></b>::            <tt>:auto</tt>
  # <b><tt>:quote_char</tt></b>::         <tt>'"'</tt>
  # <b><tt>:field_size_limit</tt></b>::   +nil+
  # <b><tt>:converters</tt></b>::         +nil+
  # <b><tt>:unconverted_fields</tt></b>:: +nil+
  # <b><tt>:headers</tt></b>::            +false+
  # <b><tt>:return_headers</tt></b>::     +false+
  # <b><tt>:header_converters</tt></b>::  +nil+
  # <b><tt>:skip_blanks</tt></b>::        +false+
  # <b><tt>:force_quotes</tt></b>::       +false+
  # <b><tt>:skip_lines</tt></b>::         +nil+
  # <b><tt>:liberal_parsing</tt></b>::    +false+
  #
  DEFAULT_OPTIONS = {
    col_sep:            ",",
    row_sep:            :auto,
    quote_char:         '"',
    field_size_limit:   nil,
    converters:         nil,
    unconverted_fields: nil,
    headers:            false,
    return_headers:     false,
    header_converters:  nil,
    skip_blanks:        false,
    force_quotes:       false,
    skip_lines:         nil,
    liberal_parsing:    false,
  }.freeze

  #
  # This method will return a HBCSV instance, just like HBCSV::new(), but the
  # instance will be cached and returned for all future calls to this method for
  # the same +data+ object (tested by Object#object_id()) with the same
  # +options+.
  #
  # If a block is given, the instance is passed to the block and the return
  # value becomes the return value of the block.
  #
  def self.instance(data = $stdout, **options)
    # create a _signature_ for this method call, data object and options
    sig = [data.object_id] +
          options.values_at(*DEFAULT_OPTIONS.keys.sort_by { |sym| sym.to_s })

    # fetch or create the instance for this signature
    @@instances ||= Hash.new
    instance = (@@instances[sig] ||= new(data, options))

    if block_given?
      yield instance  # run block, if given, returning result
    else
      instance        # or return the instance
    end
  end

  #
  # :call-seq:
  #   filter( **options ) { |row| ... }
  #   filter( input, **options ) { |row| ... }
  #   filter( input, output, **options ) { |row| ... }
  #
  # This method is a convenience for building Unix-like filters for HBCSV data.
  # Each row is yielded to the provided block which can alter it as needed.
  # After the block returns, the row is appended to +output+ altered or not.
  #
  # The +input+ and +output+ arguments can be anything HBCSV::new() accepts
  # (generally String or IO objects).  If not given, they default to
  # <tt>ARGF</tt> and <tt>$stdout</tt>.
  #
  # The +options+ parameter is also filtered down to HBCSV::new() after some
  # clever key parsing.  Any key beginning with <tt>:in_</tt> or
  # <tt>:input_</tt> will have that leading identifier stripped and will only
  # be used in the +options+ Hash for the +input+ object.  Keys starting with
  # <tt>:out_</tt> or <tt>:output_</tt> affect only +output+.  All other keys
  # are assigned to both objects.
  #
  # The <tt>:output_row_sep</tt> +option+ defaults to
  # <tt>$INPUT_RECORD_SEPARATOR</tt> (<tt>$/</tt>).
  #
  def self.filter(input=nil, output=nil, **options)
    # parse options for input, output, or both
    in_options, out_options = Hash.new, {row_sep: $INPUT_RECORD_SEPARATOR}
    options.each do |key, value|
      case key.to_s
      when /\Ain(?:put)?_(.+)\Z/
        in_options[$1.to_sym] = value
      when /\Aout(?:put)?_(.+)\Z/
        out_options[$1.to_sym] = value
      else
        in_options[key]  = value
        out_options[key] = value
      end
    end
    # build input and output wrappers
    input  = new(input  || ARGF,    in_options)
    output = new(output || $stdout, out_options)

    # read, yield, write
    input.each do |row|
      yield row
      output << row
    end
  end

  #
  # This method is intended as the primary interface for reading HBCSV files.  You
  # pass a +path+ and any +options+ you wish to set for the read.  Each row of
  # file will be passed to the provided +block+ in turn.
  #
  # The +options+ parameter can be anything HBCSV::new() understands.  This method
  # also understands an additional <tt>:encoding</tt> parameter that you can use
  # to specify the Encoding of the data in the file to be read. You must provide
  # this unless your data is in Encoding::default_external().  HBCSV will use this
  # to determine how to parse the data.  You may provide a second Encoding to
  # have the data transcoded as it is read.  For example,
  # <tt>encoding: "UTF-32BE:UTF-8"</tt> would read UTF-32BE data from the file
  # but transcode it to UTF-8 before HBCSV parses it.
  #
  def self.foreach(path, **options, &block)
    return to_enum(__method__, path, options) unless block_given?
    open(path, options) do |csv|
      csv.each(&block)
    end
  end

  #
  # :call-seq:
  #   generate( str, **options ) { |csv| ... }
  #   generate( **options ) { |csv| ... }
  #
  # This method wraps a String you provide, or an empty default String, in a
  # HBCSV object which is passed to the provided block.  You can use the block to
  # append HBCSV rows to the String and when the block exits, the final String
  # will be returned.
  #
  # Note that a passed String *is* modified by this method.  Call dup() before
  # passing if you need a new String.
  #
  # The +options+ parameter can be anything HBCSV::new() understands.  This method
  # understands an additional <tt>:encoding</tt> parameter when not passed a
  # String to set the base Encoding for the output.  HBCSV needs this hint if you
  # plan to output non-ASCII compatible data.
  #
  def self.generate(str=nil, **options)
    # add a default empty String, if none was given
    if str
      str = StringIO.new(str)
      str.seek(0, IO::SEEK_END)
    else
      encoding = options[:encoding]
      str      = String.new
      str.force_encoding(encoding) if encoding
    end
    csv = new(str, options) # wrap
    yield csv         # yield for appending
    csv.string        # return final String
  end

  #
  # This method is a shortcut for converting a single row (Array) into a HBCSV
  # String.
  #
  # The +options+ parameter can be anything HBCSV::new() understands.  This method
  # understands an additional <tt>:encoding</tt> parameter to set the base
  # Encoding for the output.  This method will try to guess your Encoding from
  # the first non-+nil+ field in +row+, if possible, but you may need to use
  # this parameter as a backup plan.
  #
  # The <tt>:row_sep</tt> +option+ defaults to <tt>$INPUT_RECORD_SEPARATOR</tt>
  # (<tt>$/</tt>) when calling this method.
  #
  def self.generate_line(row, **options)
    options = {row_sep: $INPUT_RECORD_SEPARATOR}.merge(options)
    str = String.new
    if options[:encoding]
      str.force_encoding(options[:encoding])
    elsif field = row.find { |f| not f.nil? }
      str.force_encoding(String(field).encoding)
    end
    (new(str, options) << row).string
  end

  #
  # :call-seq:
  #   open( filename, mode = "rb", **options ) { |faster_csv| ... }
  #   open( filename, **options ) { |faster_csv| ... }
  #   open( filename, mode = "rb", **options )
  #   open( filename, **options )
  #
  # This method opens an IO object, and wraps that with HBCSV.  This is intended
  # as the primary interface for writing a HBCSV file.
  #
  # You must pass a +filename+ and may optionally add a +mode+ for Ruby's
  # open().  You may also pass an optional Hash containing any +options+
  # HBCSV::new() understands as the final argument.
  #
  # This method works like Ruby's open() call, in that it will pass a HBCSV object
  # to a provided block and close it when the block terminates, or it will
  # return the HBCSV object when no block is provided.  (*Note*: This is different
  # from the Ruby 1.8 HBCSV library which passed rows to the block.  Use
  # HBCSV::foreach() for that behavior.)
  #
  # You must provide a +mode+ with an embedded Encoding designator unless your
  # data is in Encoding::default_external().  HBCSV will check the Encoding of the
  # underlying IO object (set by the +mode+ you pass) to determine how to parse
  # the data.   You may provide a second Encoding to have the data transcoded as
  # it is read just as you can with a normal call to IO::open().  For example,
  # <tt>"rb:UTF-32BE:UTF-8"</tt> would read UTF-32BE data from the file but
  # transcode it to UTF-8 before HBCSV parses it.
  #
  # An opened HBCSV object will delegate to many IO methods for convenience.  You
  # may call:
  #
  # * binmode()
  # * binmode?()
  # * close()
  # * close_read()
  # * close_write()
  # * closed?()
  # * eof()
  # * eof?()
  # * external_encoding()
  # * fcntl()
  # * fileno()
  # * flock()
  # * flush()
  # * fsync()
  # * internal_encoding()
  # * ioctl()
  # * isatty()
  # * path()
  # * pid()
  # * pos()
  # * pos=()
  # * reopen()
  # * seek()
  # * stat()
  # * sync()
  # * sync=()
  # * tell()
  # * to_i()
  # * to_io()
  # * truncate()
  # * tty?()
  #
  def self.open(filename, mode="r", **options)
    # wrap a File opened with the remaining +args+ with no newline
    # decorator
    file_opts = {universal_newline: false}.merge(options)

    begin
      f = File.open(filename, mode, file_opts)
    rescue ArgumentError => e
      raise unless /needs binmode/.match?(e.message) and mode == "r"
      mode = "rb"
      file_opts = {encoding: Encoding.default_external}.merge(file_opts)
      retry
    end
    begin
      csv = new(f, options)
    rescue Exception
      f.close
      raise
    end

    # handle blocks like Ruby's open(), not like the HBCSV library
    if block_given?
      begin
        yield csv
      ensure
        csv.close
      end
    else
      csv
    end
  end

  #
  # :call-seq:
  #   parse( str, **options ) { |row| ... }
  #   parse( str, **options )
  #
  # This method can be used to easily parse HBCSV out of a String.  You may either
  # provide a +block+ which will be called with each row of the String in turn,
  # or just use the returned Array of Arrays (when no +block+ is given).
  #
  # You pass your +str+ to read from, and an optional +options+ containing
  # anything HBCSV::new() understands.
  #
  def self.parse(*args, &block)
    csv = new(*args)

    return csv.each(&block) if block_given?

    # slurp contents, if no block is given
    begin
      csv.read
    ensure
      csv.close
    end
  end

  #
  # This method is a shortcut for converting a single line of a HBCSV String into
  # an Array.  Note that if +line+ contains multiple rows, anything beyond the
  # first row is ignored.
  #
  # The +options+ parameter can be anything HBCSV::new() understands.
  #
  def self.parse_line(line, **options)
    new(line, options).shift
  end

  #
  # Use to slurp a HBCSV file into an Array of Arrays.  Pass the +path+ to the
  # file and any +options+ HBCSV::new() understands.  This method also understands
  # an additional <tt>:encoding</tt> parameter that you can use to specify the
  # Encoding of the data in the file to be read. You must provide this unless
  # your data is in Encoding::default_external().  HBCSV will use this to determine
  # how to parse the data.  You may provide a second Encoding to have the data
  # transcoded as it is read.  For example,
  # <tt>encoding: "UTF-32BE:UTF-8"</tt> would read UTF-32BE data from the file
  # but transcode it to UTF-8 before HBCSV parses it.
  #
  def self.read(path, *options)
    open(path, *options) { |csv| csv.read }
  end

  # Alias for HBCSV::read().
  def self.readlines(*args)
    read(*args)
  end

  #
  # A shortcut for:
  #
  #   HBCSV.read( path, { headers:           true,
  #                     converters:        :numeric,
  #                     header_converters: :symbol }.merge(options) )
  #
  def self.table(path, **options)
    read( path, { headers:           true,
                  converters:        :numeric,
                  header_converters: :symbol }.merge(options) )
  end

  #
  # This constructor will wrap either a String or IO object passed in +data+ for
  # reading and/or writing.  In addition to the HBCSV instance methods, several IO
  # methods are delegated.  (See HBCSV::open() for a complete list.)  If you pass
  # a String for +data+, you can later retrieve it (after writing to it, for
  # example) with HBCSV.string().
  #
  # Note that a wrapped String will be positioned at the beginning (for
  # reading).  If you want it at the end (for writing), use HBCSV::generate().
  # If you want any other positioning, pass a preset StringIO object instead.
  #
  # You may set any reading and/or writing preferences in the +options+ Hash.
  # Available options are:
  #
  # <b><tt>:col_sep</tt></b>::            The String placed between each field.
  #                                       This String will be transcoded into
  #                                       the data's Encoding before parsing.
  # <b><tt>:row_sep</tt></b>::            The String appended to the end of each
  #                                       row.  This can be set to the special
  #                                       <tt>:auto</tt> setting, which requests
  #                                       that HBCSV automatically discover this
  #                                       from the data.  Auto-discovery reads
  #                                       ahead in the data looking for the next
  #                                       <tt>"\r\n"</tt>, <tt>"\n"</tt>, or
  #                                       <tt>"\r"</tt> sequence.  A sequence
  #                                       will be selected even if it occurs in
  #                                       a quoted field, assuming that you
  #                                       would have the same line endings
  #                                       there.  If none of those sequences is
  #                                       found, +data+ is <tt>ARGF</tt>,
  #                                       <tt>STDIN</tt>, <tt>STDOUT</tt>, or
  #                                       <tt>STDERR</tt>, or the stream is only
  #                                       available for output, the default
  #                                       <tt>$INPUT_RECORD_SEPARATOR</tt>
  #                                       (<tt>$/</tt>) is used.  Obviously,
  #                                       discovery takes a little time.  Set
  #                                       manually if speed is important.  Also
  #                                       note that IO objects should be opened
  #                                       in binary mode on Windows if this
  #                                       feature will be used as the
  #                                       line-ending translation can cause
  #                                       problems with resetting the document
  #                                       position to where it was before the
  #                                       read ahead. This String will be
  #                                       transcoded into the data's Encoding
  #                                       before parsing.
  # <b><tt>:quote_char</tt></b>::         The character used to quote fields.
  #                                       This has to be a single character
  #                                       String.  This is useful for
  #                                       application that incorrectly use
  #                                       <tt>'</tt> as the quote character
  #                                       instead of the correct <tt>"</tt>.
  #                                       HBCSV will always consider a double
  #                                       sequence of this character to be an
  #                                       escaped quote. This String will be
  #                                       transcoded into the data's Encoding
  #                                       before parsing.
  # <b><tt>:field_size_limit</tt></b>::   This is a maximum size HBCSV will read
  #                                       ahead looking for the closing quote
  #                                       for a field.  (In truth, it reads to
  #                                       the first line ending beyond this
  #                                       size.)  If a quote cannot be found
  #                                       within the limit HBCSV will raise a
  #                                       MalformedCSVError, assuming the data
  #                                       is faulty.  You can use this limit to
  #                                       prevent what are effectively DoS
  #                                       attacks on the parser.  However, this
  #                                       limit can cause a legitimate parse to
  #                                       fail and thus is set to +nil+, or off,
  #                                       by default.
  # <b><tt>:converters</tt></b>::         An Array of names from the Converters
  #                                       Hash and/or lambdas that handle custom
  #                                       conversion.  A single converter
  #                                       doesn't have to be in an Array.  All
  #                                       built-in converters try to transcode
  #                                       fields to UTF-8 before converting.
  #                                       The conversion will fail if the data
  #                                       cannot be transcoded, leaving the
  #                                       field unchanged.
  # <b><tt>:unconverted_fields</tt></b>:: If set to +true+, an
  #                                       unconverted_fields() method will be
  #                                       added to all returned rows (Array or
  #                                       HBCSV::Row) that will return the fields
  #                                       as they were before conversion.  Note
  #                                       that <tt>:headers</tt> supplied by
  #                                       Array or String were not fields of the
  #                                       document and thus will have an empty
  #                                       Array attached.
  # <b><tt>:headers</tt></b>::            If set to <tt>:first_row</tt> or
  #                                       +true+, the initial row of the HBCSV
  #                                       file will be treated as a row of
  #                                       headers.  If set to an Array, the
  #                                       contents will be used as the headers.
  #                                       If set to a String, the String is run
  #                                       through a call of HBCSV::parse_line()
  #                                       with the same <tt>:col_sep</tt>,
  #                                       <tt>:row_sep</tt>, and
  #                                       <tt>:quote_char</tt> as this instance
  #                                       to produce an Array of headers.  This
  #                                       setting causes HBCSV#shift() to return
  #                                       rows as HBCSV::Row objects instead of
  #                                       Arrays and HBCSV#read() to return
  #                                       HBCSV::Table objects instead of an Array
  #                                       of Arrays.
  # <b><tt>:return_headers</tt></b>::     When +false+, header rows are silently
  #                                       swallowed.  If set to +true+, header
  #                                       rows are returned in a HBCSV::Row object
  #                                       with identical headers and
  #                                       fields (save that the fields do not go
  #                                       through the converters).
  # <b><tt>:write_headers</tt></b>::      When +true+ and <tt>:headers</tt> is
  #                                       set, a header row will be added to the
  #                                       output.
  # <b><tt>:header_converters</tt></b>::  Identical in functionality to
  #                                       <tt>:converters</tt> save that the
  #                                       conversions are only made to header
  #                                       rows.  All built-in converters try to
  #                                       transcode headers to UTF-8 before
  #                                       converting.  The conversion will fail
  #                                       if the data cannot be transcoded,
  #                                       leaving the header unchanged.
  # <b><tt>:skip_blanks</tt></b>::        When set to a +true+ value, HBCSV will
  #                                       skip over any empty rows. Note that
  #                                       this setting will not skip rows that
  #                                       contain column separators, even if
  #                                       the rows contain no actual data. If
  #                                       you want to skip rows that contain
  #                                       separators but no content, consider
  #                                       using <tt>:skip_lines</tt>, or
  #                                       inspecting fields.compact.empty? on
  #                                       each row.
  # <b><tt>:force_quotes</tt></b>::       When set to a +true+ value, HBCSV will
  #                                       quote all HBCSV fields it creates.
  # <b><tt>:skip_lines</tt></b>::         When set to an object responding to
  #                                       <tt>match</tt>, every line matching
  #                                       it is considered a comment and ignored
  #                                       during parsing. When set to a String,
  #                                       it is first converted to a Regexp.
  #                                       When set to +nil+ no line is considered
  #                                       a comment. If the passed object does
  #                                       not respond to <tt>match</tt>,
  #                                       <tt>ArgumentError</tt> is thrown.
  # <b><tt>:liberal_parsing</tt></b>::    When set to a +true+ value, HBCSV will
  #                                       attempt to parse input not conformant
  #                                       with RFC 4180, such as double quotes
  #                                       in unquoted fields.
  # <b><tt>:nil_value</tt></b>::          TODO: WRITE ME.
  # <b><tt>:empty_value</tt></b>::        TODO: WRITE ME.
  #
  # See HBCSV::DEFAULT_OPTIONS for the default settings.
  #
  # Options cannot be overridden in the instance methods for performance reasons,
  # so be sure to set what you want here.
  #
  def initialize(data, col_sep: ",", row_sep: :auto, quote_char: '"', field_size_limit:   nil,
                 converters: nil, unconverted_fields: nil, headers: false, return_headers: false,
                 write_headers: nil, header_converters: nil, skip_blanks: false, force_quotes: false,
                 skip_lines: nil, liberal_parsing: false, internal_encoding: nil, external_encoding: nil, encoding: nil,
                 nil_value: nil,
                 empty_value: "")
    raise ArgumentError.new("Cannot parse nil as HBCSV") if data.nil?

    # create the IO object we will read from
    @io = data.is_a?(String) ? StringIO.new(data) : data
    @encoding = determine_encoding(encoding, internal_encoding)
    #
    # prepare for building safe regular expressions in the target encoding,
    # if we can transcode the needed characters
    #
    @re_esc   = "\\".encode(@encoding).freeze rescue ""
    @re_chars = /#{%"[-\\]\\[\\.^$?*+{}()|# \r\n\t\f\v]".encode(@encoding)}/
    @unconverted_fields = unconverted_fields

    # Stores header row settings and loads header converters, if needed.
    @use_headers    = headers
    @return_headers = return_headers
    @write_headers  = write_headers

    # headers must be delayed until shift(), in case they need a row of content
    @headers = nil

    @nil_value = nil_value
    @empty_value = empty_value
    @empty_value_is_empty_string = (empty_value == "")

    init_separators(col_sep, row_sep, quote_char, force_quotes)
    init_parsers(skip_blanks, field_size_limit, liberal_parsing)
    init_converters(converters, :@converters, :convert)
    init_converters(header_converters, :@header_converters, :header_convert)
    init_comments(skip_lines)

    @force_encoding = !!encoding

    # track our own lineno since IO gets confused about line-ends is HBCSV fields
    @lineno = 0

    # make sure headers have been assigned
    if header_row? and [Array, String].include? @use_headers.class and @write_headers
      parse_headers  # won't read data for Array or String
      self << @headers
    end
  end

  #
  # The encoded <tt>:col_sep</tt> used in parsing and writing.  See HBCSV::new
  # for details.
  #
  attr_reader :col_sep
  #
  # The encoded <tt>:row_sep</tt> used in parsing and writing.  See HBCSV::new
  # for details.
  #
  attr_reader :row_sep
  #
  # The encoded <tt>:quote_char</tt> used in parsing and writing.  See HBCSV::new
  # for details.
  #
  attr_reader :quote_char
  # The limit for field size, if any.  See HBCSV::new for details.
  attr_reader :field_size_limit

  # The regex marking a line as a comment. See HBCSV::new for details
  attr_reader :skip_lines

  #
  # Returns the current list of converters in effect.  See HBCSV::new for details.
  # Built-in converters will be returned by name, while others will be returned
  # as is.
  #
  def converters
    @converters.map do |converter|
      name = Converters.rassoc(converter)
      name ? name.first : converter
    end
  end
  #
  # Returns +true+ if unconverted_fields() to parsed results.  See HBCSV::new
  # for details.
  #
  def unconverted_fields?() @unconverted_fields end
  #
  # Returns +nil+ if headers will not be used, +true+ if they will but have not
  # yet been read, or the actual headers after they have been read.  See
  # HBCSV::new for details.
  #
  def headers
    @headers || true if @use_headers
  end
  #
  # Returns +true+ if headers will be returned as a row of results.
  # See HBCSV::new for details.
  #
  def return_headers?()     @return_headers     end
  # Returns +true+ if headers are written in output. See HBCSV::new for details.
  def write_headers?()      @write_headers      end
  #
  # Returns the current list of converters in effect for headers.  See HBCSV::new
  # for details.  Built-in converters will be returned by name, while others
  # will be returned as is.
  #
  def header_converters
    @header_converters.map do |converter|
      name = HeaderConverters.rassoc(converter)
      name ? name.first : converter
    end
  end
  #
  # Returns +true+ blank lines are skipped by the parser. See HBCSV::new
  # for details.
  #
  def skip_blanks?()        @skip_blanks        end
  # Returns +true+ if all output fields are quoted. See HBCSV::new for details.
  def force_quotes?()       @force_quotes       end
  # Returns +true+ if illegal input is handled. See HBCSV::new for details.
  def liberal_parsing?()    @liberal_parsing    end

  #
  # The Encoding HBCSV is parsing or writing in.  This will be the Encoding you
  # receive parsed data in and/or the Encoding data will be written in.
  #
  attr_reader :encoding

  #
  # The line number of the last row read from this file.  Fields with nested
  # line-end characters will not affect this count.
  #
  attr_reader :lineno, :line

  ### IO and StringIO Delegation ###

  extend Forwardable
  def_delegators :@io, :binmode, :binmode?, :close, :close_read, :close_write,
                       :closed?, :eof, :eof?, :external_encoding, :fcntl,
                       :fileno, :flock, :flush, :fsync, :internal_encoding,
                       :ioctl, :isatty, :path, :pid, :pos, :pos=, :reopen,
                       :seek, :stat, :string, :sync, :sync=, :tell, :to_i,
                       :to_io, :truncate, :tty?

  # Rewinds the underlying IO object and resets HBCSV's lineno() counter.
  def rewind
    @headers = nil
    @lineno  = 0

    @io.rewind
  end

  ### End Delegation ###

  #
  # The primary write method for wrapped Strings and IOs, +row+ (an Array or
  # HBCSV::Row) is converted to HBCSV and appended to the data source.  When a
  # HBCSV::Row is passed, only the row's fields() are appended to the output.
  #
  # The data source must be open for writing.
  #
  def <<(row)
    # make sure headers have been assigned
    if header_row? and [Array, String].include? @use_headers.class and !@write_headers
      parse_headers  # won't read data for Array or String
    end

    # handle HBCSV::Row objects and Hashes
    row = case row
          when self.class::Row then row.fields
          when Hash            then @headers.map { |header| row[header] }
          else                      row
          end

    @headers =  row if header_row?
    @lineno  += 1

    output = row.map(&@quote).join(@col_sep) + @row_sep  # quote and separate
    if @io.is_a?(StringIO)             and
       output.encoding != (encoding = raw_encoding)
      if @force_encoding
        output = output.encode(encoding)
      elsif (compatible_encoding = Encoding.compatible?(@io.string, output))
        @io.set_encoding(compatible_encoding)
        @io.seek(0, IO::SEEK_END)
      end
    end
    @io << output

    self  # for chaining
  end
  alias_method :add_row, :<<
  alias_method :puts,    :<<

  #
  # :call-seq:
  #   convert( name )
  #   convert { |field| ... }
  #   convert { |field, field_info| ... }
  #
  # You can use this method to install a HBCSV::Converters built-in, or provide a
  # block that handles a custom conversion.
  #
  # If you provide a block that takes one argument, it will be passed the field
  # and is expected to return the converted value or the field itself.  If your
  # block takes two arguments, it will also be passed a HBCSV::FieldInfo Struct,
  # containing details about the field.  Again, the block should return a
  # converted field or the field itself.
  #
  def convert(name = nil, &converter)
    add_converter(:@converters, self.class::Converters, name, &converter)
  end

  #
  # :call-seq:
  #   header_convert( name )
  #   header_convert { |field| ... }
  #   header_convert { |field, field_info| ... }
  #
  # Identical to HBCSV#convert(), but for header rows.
  #
  # Note that this method must be called before header rows are read to have any
  # effect.
  #
  def header_convert(name = nil, &converter)
    add_converter( :@header_converters,
                   self.class::HeaderConverters,
                   name,
                   &converter )
  end

  include Enumerable

  #
  # Yields each row of the data source in turn.
  #
  # Support for Enumerable.
  #
  # The data source must be open for reading.
  #
  def each
    if block_given?
      while row = shift
        yield row
      end
    else
      to_enum
    end
  end

  #
  # Slurps the remaining rows and returns an Array of Arrays.
  #
  # The data source must be open for reading.
  #
  def read
    rows = to_a
    if @use_headers
      Table.new(rows)
    else
      rows
    end
  end
  alias_method :readlines, :read

  # Returns +true+ if the next row read will be a header row.
  def header_row?
    @use_headers and @headers.nil?
  end

  #
  # The primary read method for wrapped Strings and IOs, a single row is pulled
  # from the data source, parsed and returned as an Array of fields (if header
  # rows are not used) or a HBCSV::Row (when header rows are used).
  #
  # The data source must be open for reading.
  #
  def shift
    #########################################################################
    ### This method is purposefully kept a bit long as simple conditional ###
    ### checks are faster than numerous (expensive) method calls.         ###
    #########################################################################

    # handle headers not based on document content
    if header_row? and @return_headers and
       [Array, String].include? @use_headers.class
      if @unconverted_fields
        return add_unconverted_fields(parse_headers, Array.new)
      else
        return parse_headers
      end
    end

    #
    # it can take multiple calls to <tt>@io.gets()</tt> to get a full line,
    # because of \r and/or \n characters embedded in quoted fields
    #
    in_extended_col = false
    csv             = Array.new

    loop do
      # add another read to the line
      unless parse = @io.gets(@row_sep)
        return nil
      end

      if in_extended_col
        @line.concat(parse)
      else
        @line = parse.clone
      end

      begin
        parse.sub!(@parsers[:line_end], "")
      rescue ArgumentError
        unless parse.valid_encoding?
          message = "Invalid byte sequence in #{parse.encoding}"
          raise MalformedCSVError.new(message, lineno + 1)
        end
        raise
      end

      if csv.empty?
        #
        # I believe a blank line should be an <tt>Array.new</tt>, not Ruby 1.8
        # HBCSV's <tt>[nil]</tt>
        #
        if parse.empty?
          @lineno += 1
          if @skip_blanks
            next
          elsif @unconverted_fields
            return add_unconverted_fields(Array.new, Array.new)
          elsif @use_headers
            return self.class::Row.new(@headers, Array.new)
          else
            return Array.new
          end
        end
      end

      next if @skip_lines and @skip_lines.match parse

      parts =  parse.split(@col_sep_split_separator, -1)
      if parts.empty?
        if in_extended_col
          csv[-1] << @col_sep   # will be replaced with a @row_sep after the parts.each loop
        else
          csv << nil
        end
      end

      # This loop is the hot path of csv parsing. Some things may be non-dry
      # for a reason. Make sure to benchmark when refactoring.
      parts.each do |part|
        if in_extended_col
          # If we are continuing a previous column
          if part.end_with?(@quote_char) && part.count(@quote_char) % 2 != 0
            # extended column ends
            csv.last << part[0..-2]
            if csv.last.match?(@parsers[:stray_quote])
              raise MalformedCSVError.new("Missing or stray quote",
                                          lineno + 1)
            end
            csv.last.gsub!(@double_quote_char, @quote_char)
            in_extended_col = false
          else
            csv.last << part << @col_sep
          end
        elsif part.start_with?(@quote_char)
          # If we are starting a new quoted column
          if part.count(@quote_char) % 2 != 0
            # start an extended column
            csv << (part[1..-1] << @col_sep)
            in_extended_col =  true
          elsif part.end_with?(@quote_char)
            # regular quoted column
            csv << part[1..-2]
            if csv.last.match?(@parsers[:stray_quote])
              raise MalformedCSVError.new("Missing or stray quote",
                                          lineno + 1)
            end
            csv.last.gsub!(@double_quote_char, @quote_char)
          elsif @liberal_parsing
            csv << part
          else
            raise MalformedCSVError.new("Missing or stray quote",
                                        lineno + 1)
          end
        elsif part.match?(@parsers[:quote_or_nl])
          # Unquoted field with bad characters.
          if part.match?(@parsers[:nl_or_lf])
            message = "Unquoted fields do not allow \\r or \\n"
            raise MalformedCSVError.new(message, lineno + 1)
          else
            if @liberal_parsing
              csv << part
            else
              raise MalformedCSVError.new("Illegal quoting", lineno + 1)
            end
          end
        else
          # Regular ole unquoted field.
          csv << (part.empty? ? nil : part)
        end
      end

      # Replace tacked on @col_sep with @row_sep if we are still in an extended
      # column.
      csv[-1][-1] = @row_sep if in_extended_col

      if in_extended_col
        # if we're at eof?(), a quoted field wasn't closed...
        if @io.eof?
          raise MalformedCSVError.new("Unclosed quoted field",
                                      lineno + 1)
        elsif @field_size_limit and csv.last.size >= @field_size_limit
          raise MalformedCSVError.new("Field size exceeded",
                                      lineno + 1)
        end
        # otherwise, we need to loop and pull some more data to complete the row
      else
        @lineno += 1

        # save fields unconverted fields, if needed...
        unconverted = csv.dup if @unconverted_fields

        if @use_headers
          # parse out header rows and handle HBCSV::Row conversions...
          csv = parse_headers(csv)
        else
          # convert fields, if needed...
          csv = convert_fields(csv)
        end

        # inject unconverted fields and accessor, if requested...
        if @unconverted_fields and not csv.respond_to? :unconverted_fields
          add_unconverted_fields(csv, unconverted)
        end

        # return the results
        break csv
      end
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift

  #
  # Returns a simplified description of the key HBCSV attributes in an
  # ASCII compatible String.
  #
  def inspect
    str = ["<#", self.class.to_s, " io_type:"]
    # show type of wrapped IO
    if    @io == $stdout then str << "$stdout"
    elsif @io == $stdin  then str << "$stdin"
    elsif @io == $stderr then str << "$stderr"
    else                      str << @io.class.to_s
    end
    # show IO.path(), if available
    if @io.respond_to?(:path) and (p = @io.path)
      str << " io_path:" << p.inspect
    end
    # show encoding
    str << " encoding:" << @encoding.name
    # show other attributes
    %w[ lineno     col_sep     row_sep
        quote_char skip_blanks liberal_parsing ].each do |attr_name|
      if a = instance_variable_get("@#{attr_name}")
        str << " " << attr_name << ":" << a.inspect
      end
    end
    if @use_headers
      str << " headers:" << headers.inspect
    end
    str << ">"
    begin
      str.join('')
    rescue  # any encoding error
      str.map do |s|
        e = Encoding::Converter.asciicompat_encoding(s.encoding)
        e ? s.encode(e) : s.force_encoding("ASCII-8BIT")
      end.join('')
    end
  end

  private

  def determine_encoding(encoding, internal_encoding)
    # honor the IO encoding if we can, otherwise default to ASCII-8BIT
    io_encoding = raw_encoding(nil)
    return io_encoding if io_encoding

    return Encoding.find(internal_encoding) if internal_encoding

    if encoding
      encoding, = encoding.split(":", 2) if encoding.is_a?(String)
      return Encoding.find(encoding)
    end

    Encoding.default_internal || Encoding.default_external
  end

  #
  # Stores the indicated separators for later use.
  #
  # If auto-discovery was requested for <tt>@row_sep</tt>, this method will read
  # ahead in the <tt>@io</tt> and try to find one.  +ARGF+, +STDIN+, +STDOUT+,
  # +STDERR+ and any stream open for output only with a default
  # <tt>@row_sep</tt> of <tt>$INPUT_RECORD_SEPARATOR</tt> (<tt>$/</tt>).
  #
  # This method also establishes the quoting rules used for HBCSV output.
  #
  def init_separators(col_sep, row_sep, quote_char, force_quotes)
    # store the selected separators
    @col_sep    = col_sep.to_s.encode(@encoding)
    if @col_sep == " "
      @col_sep_split_separator = Regexp.new(/#{Regexp.escape(@col_sep)}/)
    else
      @col_sep_split_separator = @col_sep
    end
    @row_sep    = row_sep # encode after resolving :auto
    @quote_char = quote_char.to_s.encode(@encoding)
    @double_quote_char = @quote_char * 2

    if @quote_char.length != 1
      raise ArgumentError, ":quote_char has to be a single character String"
    end

    #
    # automatically discover row separator when requested
    # (not fully encoding safe)
    #
    if @row_sep == :auto
      if [ARGF, STDIN, STDOUT, STDERR].include?(@io) or
         (defined?(Zlib) and @io.class == Zlib::GzipWriter)
        @row_sep = $INPUT_RECORD_SEPARATOR
      else
        begin
          #
          # remember where we were (pos() will raise an exception if @io is pipe
          # or not opened for reading)
          #
          saved_pos = @io.pos
          while @row_sep == :auto
            #
            # if we run out of data, it's probably a single line
            # (ensure will set default value)
            #
            break unless sample = @io.gets(nil, 1024)

            cr = encode_str("\r")
            lf = encode_str("\n")
            # extend sample if we're unsure of the line ending
            if sample.end_with?(cr)
              sample << (@io.gets(nil, 1) || "")
            end

            # try to find a standard separator
            sample.each_char.each_cons(2) do |char, next_char|
              case char
              when cr
                if next_char == lf
                  @row_sep = encode_str("\r\n")
                else
                  @row_sep = cr
                end
                break
              when lf
                @row_sep = lf
                break
              end
            end
          end

          # tricky seek() clone to work around GzipReader's lack of seek()
          @io.rewind
          # reset back to the remembered position
          while saved_pos > 1024  # avoid loading a lot of data into memory
            @io.read(1024)
            saved_pos -= 1024
          end
          @io.read(saved_pos) if saved_pos.nonzero?
        rescue IOError         # not opened for reading
          # do nothing:  ensure will set default
        rescue NoMethodError   # Zlib::GzipWriter doesn't have some IO methods
          # do nothing:  ensure will set default
        rescue SystemCallError # pipe
          # do nothing:  ensure will set default
        ensure
          #
          # set default if we failed to detect
          # (stream not opened for reading, a pipe, or a single line of data)
          #
          @row_sep = $INPUT_RECORD_SEPARATOR if @row_sep == :auto
        end
      end
    end
    @row_sep = @row_sep.to_s.encode(@encoding)

    # establish quoting rules
    @force_quotes = force_quotes
    do_quote = lambda do |field|
      field = String(field)
      encoded_quote = @quote_char.encode(field.encoding)
      encoded_quote + field.gsub(encoded_quote, encoded_quote * 2) + encoded_quote
    end
    quotable_chars = encode_str("\r\n", @col_sep, @quote_char)
    @quote         = if @force_quotes
      do_quote
    else
      lambda do |field|
        if field.nil?  # represent +nil+ fields as empty unquoted fields
          ""
        else
          field = String(field)  # Stringify fields
          # represent empty fields as empty quoted fields
          if field.empty? or
             field.count(quotable_chars).nonzero?
            do_quote.call(field)
          else
            field  # unquoted field
          end
        end
      end
    end
  end

  # Pre-compiles parsers and stores them by name for access during reads.
  def init_parsers(skip_blanks, field_size_limit, liberal_parsing)
    # store the parser behaviors
    @skip_blanks      = skip_blanks
    @field_size_limit = field_size_limit
    @liberal_parsing  = liberal_parsing

    # prebuild Regexps for faster parsing
    esc_row_sep = escape_re(@row_sep)
    esc_quote   = escape_re(@quote_char)
    @parsers = {
      # for detecting parse errors
      quote_or_nl:    encode_re("[", esc_quote, "\r\n]"),
      nl_or_lf:       encode_re("[\r\n]"),
      stray_quote:    encode_re( "[^", esc_quote, "]", esc_quote,
                                 "[^", esc_quote, "]" ),
      # safer than chomp!()
      line_end:       encode_re(esc_row_sep, "\\z"),
      # illegal unquoted characters
      return_newline: encode_str("\r\n")
    }
  end

  #
  # Loads any converters requested during construction.
  #
  # If +field_name+ is set <tt>:converters</tt> (the default) field converters
  # are set.  When +field_name+ is <tt>:header_converters</tt> header converters
  # are added instead.
  #
  # The <tt>:unconverted_fields</tt> option is also activated for
  # <tt>:converters</tt> calls, if requested.
  #
  def init_converters(converters, ivar_name, convert_method)
    converters = case converters
                 when nil then []
                 when Array then converters
                 else [converters]
                 end
    instance_variable_set(ivar_name, [])
    convert = method(convert_method)

    # load converters
    converters.each do |converter|
      if converter.is_a? Proc  # custom code block
        convert.call(&converter)
      else                     # by name
        convert.call(converter)
      end
    end
  end

  # Stores the pattern of comments to skip from the provided options.
  #
  # The pattern must respond to +.match+, else ArgumentError is raised.
  # Strings are converted to a Regexp.
  #
  # See also HBCSV.new
  def init_comments(skip_lines)
    @skip_lines = skip_lines
    @skip_lines = Regexp.new(Regexp.escape(@skip_lines)) if @skip_lines.is_a? String
    if @skip_lines and not @skip_lines.respond_to?(:match)
      raise ArgumentError, ":skip_lines has to respond to matches"
    end
  end
  #
  # The actual work method for adding converters, used by both HBCSV.convert() and
  # HBCSV.header_convert().
  #
  # This method requires the +var_name+ of the instance variable to place the
  # converters in, the +const+ Hash to lookup named converters in, and the
  # normal parameters of the HBCSV.convert() and HBCSV.header_convert() methods.
  #
  def add_converter(var_name, const, name = nil, &converter)
    if name.nil?  # custom converter
      instance_variable_get(var_name) << converter
    else          # named converter
      combo = const[name]
      case combo
      when Array  # combo converter
        combo.each do |converter_name|
          add_converter(var_name, const, converter_name)
        end
      else        # individual named converter
        instance_variable_get(var_name) << combo
      end
    end
  end

  #
  # Processes +fields+ with <tt>@converters</tt>, or <tt>@header_converters</tt>
  # if +headers+ is passed as +true+, returning the converted field set.  Any
  # converter that changes the field into something other than a String halts
  # the pipeline of conversion for that field.  This is primarily an efficiency
  # shortcut.
  #
  def convert_fields(fields, headers = false)
    if headers
      converters = @header_converters
    else
      converters = @converters
      if !@use_headers and
          converters.empty? and
          @nil_value.nil? and
          @empty_value_is_empty_string
        return fields
      end
    end

    fields.map.with_index do |field, index|
      if field.nil?
        field = @nil_value
      elsif field.empty?
        field = @empty_value unless @empty_value_is_empty_string
      end
      converters.each do |converter|
        break if headers && field.nil?
        field = if converter.arity == 1  # straight field converter
          converter[field]
        else                             # FieldInfo converter
          header = @use_headers && !headers ? @headers[index] : nil
          converter[field, FieldInfo.new(index, lineno, header)]
        end
        break unless field.is_a? String  # short-circuit pipeline for speed
      end
      field  # final state of each field, converted or original
    end
  end

  #
  # This method is used to turn a finished +row+ into a HBCSV::Row.  Header rows
  # are also dealt with here, either by returning a HBCSV::Row with identical
  # headers and fields (save that the fields do not go through the converters)
  # or by reading past them to return a field row. Headers are also saved in
  # <tt>@headers</tt> for use in future rows.
  #
  # When +nil+, +row+ is assumed to be a header row not based on an actual row
  # of the stream.
  #
  def parse_headers(row = nil)
    if @headers.nil?                # header row
      @headers = case @use_headers  # save headers
                 # Array of headers
                 when Array then @use_headers
                 # HBCSV header String
                 when String
                   self.class.parse_line( @use_headers,
                                          col_sep:    @col_sep,
                                          row_sep:    @row_sep,
                                          quote_char: @quote_char )
                 # first row is headers
                 else            row
                 end

      # prepare converted and unconverted copies
      row      = @headers                       if row.nil?
      @headers = convert_fields(@headers, true)
      @headers.each { |h| h.freeze if h.is_a? String }

      if @return_headers                                     # return headers
        return self.class::Row.new(@headers, row, true)
      elsif not [Array, String].include? @use_headers.class  # skip to field row
        return shift
      end
    end

    self.class::Row.new(@headers, convert_fields(row))  # field row
  end

  #
  # This method injects an instance variable <tt>unconverted_fields</tt> into
  # +row+ and an accessor method for +row+ called unconverted_fields().  The
  # variable is set to the contents of +fields+.
  #
  def add_unconverted_fields(row, fields)
    class << row
      attr_reader :unconverted_fields
    end
    row.instance_variable_set(:@unconverted_fields, fields)
    row
  end

  #
  # This method is an encoding safe version of Regexp::escape().  It will escape
  # any characters that would change the meaning of a regular expression in the
  # encoding of +str+.  Regular expression characters that cannot be transcoded
  # to the target encoding will be skipped and no escaping will be performed if
  # a backslash cannot be transcoded.
  #
  def escape_re(str)
    str.gsub(@re_chars) {|c| @re_esc + c}
  end

  #
  # Builds a regular expression in <tt>@encoding</tt>.  All +chunks+ will be
  # transcoded to that encoding.
  #
  def encode_re(*chunks)
    Regexp.new(encode_str(*chunks))
  end

  #
  # Builds a String in <tt>@encoding</tt>.  All +chunks+ will be transcoded to
  # that encoding.
  #
  def encode_str(*chunks)
    chunks.map { |chunk| chunk.encode(@encoding.name) }.join('')
  end

  #
  # Returns the encoding of the internal IO object or the +default+ if the
  # encoding cannot be determined.
  #
  def raw_encoding(default = Encoding::ASCII_8BIT)
    if @io.respond_to? :internal_encoding
      @io.internal_encoding || @io.external_encoding
    elsif @io.is_a? StringIO
      @io.string.encoding
    elsif @io.respond_to? :encoding
      @io.encoding
    else
      default
    end
  end
end

# Passes +args+ to HBCSV::instance.
#
#   HBCSV("HBCSV,data").read
#     #=> [["HBCSV", "data"]]
#
# If a block is given, the instance is passed the block and the return value
# becomes the return value of the block.
#
#   HBCSV("HBCSV,data") { |c|
#     c.read.any? { |a| a.include?("data") }
#   } #=> true
#
#   HBCSV("HBCSV,data") { |c|
#     c.read.any? { |a| a.include?("zombies") }
#   } #=> false
#
def HBCSV(*args, &block)
  HBCSV.instance(*args, &block)
end

require_relative "hb_csv/version"
require_relative "hb_csv/core_ext/array"
require_relative "hb_csv/core_ext/string"
