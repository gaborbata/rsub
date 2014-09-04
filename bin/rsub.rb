#!/usr/bin/env ruby

require 'fileutils'

# Class for representing time
class SrtTime
  # [,:] is added for some incorrectly formatted subs
  TIME_PATTERN = /(\d{2}):(\d{2}):(\d{2})[,:](\d{3})/
  TIME_FORMAT = '%02d:%02d:%02d,%03d'

  def initialize(time_str)
    h, m, s, ms = time_str.scan(TIME_PATTERN).flatten.map{ |i| Float(i) }
    @value = (h * 60.0 + m) * 60.0 + s + ms / 1000.0
  end

  def multiply!(factor)
    @value = @value * factor
  end

  def shift!(time)
    @value = @value + time
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

  def to_s(order = nil)
    return "#{order ? order : @order}\n#{@start_time.to_s} --> #{@end_time.to_s}\n#{@text}\n\n"
  end
end

# Class for representing a change command for a subtitle entry
class SrtChangeCommand
  FPS_25 = 25.0
  FPS_23 = 23.976

  def initialize(command)
    if command == 'fps25'
      @method = :multiply
      @param = FPS_23 / FPS_25
    elsif command == 'fps23'
      @method = :multiply
      @param = FPS_25 / FPS_23
    elsif command.match(/shift:-?\d+(\.\d+){0,1}/)
      @method = :shift
      @param = Float(command.split(':')[1])
    elsif command == 'rewrite'
      @method = :shift
      @param = 0.0
    end
  end

  def execute(entry)
    send(@method, entry) if @method
  end

  def valid?
    !@method.nil?
  end

  private

  def multiply(entry)
    entry.multiply!(@param)
  end

  def shift(entry)
    entry.shift!(@param)
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
       warn "***** ERROR: in file: [#{in_file_name}] with entry: #{buffer}\n"
       trace = error.backtrace.join("\n")
       warn "Backtrace: #{error}\n#{trace}\n\n"
       entry_list = []
    end
    puts "Done: #{entry_list.size} entries have been read."
    return entry_list
  end

  def write(entry_list, create_backup = false, recount = false)
    if entry_list && !entry_list.empty?
      backup if create_backup
      puts "Writing subtitles to '#{@file_name}'..."
      file = File.open(@file_name, "w:#{@encoding}")
      counter = 0
      entry_list.each do |entry|
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

# Main
USE_BACKUP_FILE_AS_INPUT = false
CREATE_BACKUP_FILE = true
RECOUNT_ORDER = true

files = Dir.glob('**/*.srt')
if files.empty?
  puts "Could not found subtitle files in the current directory or its subdirectories."
else
  puts "The following file(s) are going to be modified:\n#{files.join("\n")}\n\n"

  puts "The following commands can be used:\n" +
    "  fps23    : 25fps -> 23,976fps\n" +
    "  fps25    : 23.976fps -> 25fps\n" +
    "  shift:N  : shift subtitles by N seconds\n\n" +
    "Examples:\n" +
    "  fps23,shift:5  : 25fps -> 23,976fps and shift subtitles by 5 seconds forward\n" +
    "  shift:-10.5    : shift subtitles by 10 seconds and 5 milliseconds backward\n\n"

  print "Please enter command: "
  input = STDIN.gets.chomp.split(',')

  commands = []
  input.each do |command|
    cmd = SrtChangeCommand.new(command)
    commands.push(cmd) if cmd.valid?
  end

  if commands.empty?
    puts "No commands are recognized, nothing to do..."
  else
    files.each do |file|
      srt_file = SrtFile.new(file)
      entry_list = srt_file.read(USE_BACKUP_FILE_AS_INPUT)
      entry_list.each do |entry|
        commands.each do |command|
          command.execute(entry)
        end
      end
      srt_file.write(entry_list, CREATE_BACKUP_FILE, RECOUNT_ORDER)
    end
  end
end

puts; print('Press ENTER to exit...'); STDIN.gets
