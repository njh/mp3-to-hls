require 'test_helper'

class MP3toHLSTest < Minitest::Test
  def setup
    @mp3hls = MP3toHLS.new

    # Create a tempory directory that files can be written to
    tempfile = Tempfile.new('mp3-to-hls-test')
    @testdir = tempfile.path
    tempfile.close!
    Dir.mkdir(@testdir)
  end

  def teardown
    # Delete the temporary directory and its contents
    if Dir.exist?(@testdir)
      Dir.foreach(@testdir) do |filename|
        filepath = File.join(@testdir, filename)
        File.delete(filepath) if File.file?(filepath)
      end
      Dir.rmdir(@testdir)
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::MP3toHLS::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end
