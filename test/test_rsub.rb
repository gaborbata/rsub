require 'test/unit'
require_relative '../bin/rsub.rb'

class TestRsub < Test::Unit::TestCase

  def setup
    @entry = SrtEntry.new(1, '00:02:17,440', '00:02:20,375', "Senator, we're making\nour final approach into <i>Coruscant</i>.")
  end

  def teardown
    # Nothing really
  end

  def test_parsing_srt_time
    assert_equal('00:02:17,439', SrtTime.new('00:02:17,440').to_s)
  end

  def test_parsing_incorreclty_formatted_srt_time
    assert_equal('00:02:17,439', SrtTime.new('00:02:17:440').to_s)
  end

  def test_srt_entry
    assert_equal("1\n00:02:17,439 --> 00:02:20,375\nSenator, we're making\nour final approach into Coruscant.\n\n", @entry.to_s)
  end

  def test_srt_entry_fps
    SrtChangeCommand.new(:fps, '25').execute(@entry)
    assert_equal("1\n00:02:11,810 --> 00:02:14,625\nSenator, we're making\nour final approach into Coruscant.\n\n", @entry.to_s)
  end

  def test_srt_entry_shift
    SrtChangeCommand.new(:shift, 10.5).execute(@entry)
    assert_equal("1\n00:02:27,939 --> 00:02:30,875\nSenator, we're making\nour final approach into Coruscant.\n\n", @entry.to_s)
  end

end
