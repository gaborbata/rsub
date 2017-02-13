#!/usr/bin/env ruby

# rsub.rb - Ruby script which changes the timing of srt (SubRip) subtitle files.
#
# Copyright (c) 2014-2017 Gabor Bata
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'fileutils'
require 'optparse'

# Class for representing time
class SrtTime
  # [,:] is added for some incorrectly formatted subs
  TIME_PATTERN = /(\d{2}):(\d{2}):(\d{2})[,:](\d{3})/
  TIME_FORMAT = '%02d:%02d:%02d,%03d'

  def initialize(time_str)
    @value = -1.0
    begin
      h, m, s, ms = time_str.scan(TIME_PATTERN).flatten.map{ |i| Float(i) }
      @value = (h * 60.0 + m) * 60.0 + s + ms / 1000.0
    rescue
       warn "ERROR: could not read time entry: #{time_str}"
    end
  end

  def multiply!(factor)
    @value = @value * factor
  end

  def shift!(time)
    @value = @value + time
  end

  def valid?
    @value >= 0.0
  end

  def to_s
    s = @value.floor
    ms = ((@value - s) * 1000.0).to_i
    m = s / 60
    s = s - m * 60
    h = m / 60
    m = m - h * 60
    return sprintf(TIME_FORMAT, h, m, s, ms)
  end
end

# Class for representing an srt subtitle entry
class SrtEntry
  def initialize(order, start_time, end_time, text)
    @order = order
    @start_time = SrtTime.new(start_time)
    @end_time = SrtTime.new(end_time)
    # '<i>' and '</i>' will be removed as they are not supported by all players
    @text = text.gsub('<i>', '').gsub('</i>', '')
  end

  def multiply!(factor)
    @start_time.multiply!(factor)
    @end_time.multiply!(factor)
  end

  def shift!(time)
    @start_time.shift!(time)
    @end_time.shift!(time)
  end

  def valid?
    @start_time.valid? && @end_time.valid?
  end

  def to_s(order = nil)
    return "#{order ? order : @order}\n#{@start_time.to_s} --> #{@end_time.to_s}\n#{@text}\n\n"
  end
end

# Class for reading/writing srt files
class SrtFile
  BACKUP_EXTENSION = '.bak'

  def initialize(file_name, encoding = 'ISO-8859-2')
    @file_name = file_name
    @encoding = encoding
  end

  def read(use_backup_as_input = false)
    name_postfix = use_backup_as_input && File.exist?("#{@file_name}#{BACKUP_EXTENSION}") ? BACKUP_EXTENSION : ''
    in_file_name = "#{@file_name}#{name_postfix}"
    puts "Reading subtitles from '#{in_file_name}'..."
    entry_list = []
    buffer = []
    file = File.open("#{in_file_name}", "r:#{@encoding}")
    begin
      file.each_line do |line|
        entry_line = line.chomp.strip
        if entry_line.empty? && !buffer.empty?
          flush_buffer(entry_list, buffer)
        elsif !entry_line.empty?
          buffer.push(entry_line)
        end
      end
      flush_buffer(entry_list, buffer) if !buffer.empty?
    rescue => error
       warn "ERROR: in file: [#{in_file_name}] with entry: #{buffer}\n"
       trace = error.backtrace.join("\n")
       warn "Backtrace: #{error}\n#{trace}\n\n"
       entry_list = []
    end
    file.close
    puts "Done: #{entry_list.size} entries have been read."
    return entry_list
  end

  def write(entry_list, create_backup = false, recount = true)
    if entry_list && !entry_list.empty?
      backup if create_backup
      puts "Writing subtitles to '#{@file_name}'..."
      file = File.open(@file_name, "w:#{@encoding}")
      counter = 0
      entry_list.each do |entry|
        next if !entry.valid?
        counter += 1
        file.print(entry.to_s(recount ? counter : nil))
      end
      file.close
      puts "Done: #{counter} entries have been written."
    end
  end

  def backup
    backup_name = @file_name + BACKUP_EXTENSION
    if File.exist?(@file_name) && !File.exist?(backup_name)
      puts "Creating backup file '#{backup_name}'..."
      FileUtils.cp(@file_name, backup_name)
    end
  end

  private

  def flush_buffer(entry_list, buffer)
    range = buffer[1].split(' --> ')
    entry = SrtEntry.new(buffer[0], range[0], range[1], buffer[2..-1].join("\n"))
    entry_list.push(entry)
    buffer.clear
  end
end

# Class for representing a change command for a subtitle entry
class SrtChangeCommand
  FPS_25 = 25.0
  FPS_23 = 23.976

  def initialize(command, argument)
    case command
    when :fps
      case argument
      when '23'
        @method = :multiply!
        @param = FPS_25 / FPS_23
      when '25'
        @method = :multiply!
        @param = FPS_23 / FPS_25
      end
    when :shift
      if argument
        @method = :shift!
        @param = argument
      end
    end
  end

  def execute(entry)
    entry.send(@method, @param) if valid?
  end

  def valid?
    !@method.nil?
  end
end

# Parse command-line options
def parse_options(args)
  options = {}
  options[:create_backup] = true
  options[:use_backup_as_input] = false
  options[:recount] = true
  options[:encoding] = "ISO-8859-2"
  begin
    optparser = OptionParser.new do |opts|
      opts.banner = "Usage: rsub.rb [options] file_path"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-s", "--shift N", Float, "Shift subtitles by N seconds (float)") do |seconds|
        options[:shift] = seconds
      end

      opts.on("-f", "--fps FPS", ["23", "25"], "Change frame rate (23, 25)", "23: 25.000 fps -> 23,976 fps", "25: 23.976 fps -> 25.000 fps") do |fps|
        options[:fps] = fps
      end

      opts.on("-b", "--no-backup", "Do not create backup files") do
        options[:create_backup] = false
      end

      opts.on("-u", "--use-backup-as-input", "Use backup files as input (if exist)") do
        options[:use_backup_as_input] = true
      end

      opts.on("-r", "--no-recount", "Do not recount subtitle numbering") do
        options[:recount] = false
      end

      opts.on("-e", "--encoding ENCODING", "Subtitle encoding (default: #{options[:encoding]})") do |encoding|
        options[:encoding] = encoding
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end
    optparser.parse!

    if args.empty?
      puts "#{optparser.help}\n"
      raise "missing file_path"
    else
      file_path = args[0]
      # ensure file path ends with the '.srt' extension
      options[:file_path] = "#{file_path}#{!file_path.downcase.end_with?('.srt') ? '.srt' : ''}"
    end
  rescue => error
    warn "ERROR: #{error}"
    exit
  end
  return options
end

def main(options)
  files = Dir.glob(options[:file_path])
  if files.empty?
    warn "Could not found subtitle files on the given path: '#{options[:file_path]}'"
  else
    commands = []
    [:fps, :shift].each do |command|
      cmd = SrtChangeCommand.new(command, options[command])
      commands.push(cmd) if cmd.valid?
    end
    if commands.empty?
      warn "Nothing to change..."
    else
      files.each do |file|
        srt_file = SrtFile.new(file, options[:encoding])
        entry_list = srt_file.read(options[:use_backup_as_input])
        entry_list.each do |entry|
          commands.each do |command|
            command.execute(entry)
          end
        end
        srt_file.write(entry_list, options[:create_backup], options[:recount])
      end
    end
  end
end

main(parse_options(ARGV))
