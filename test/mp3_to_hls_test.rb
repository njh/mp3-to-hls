require 'test_helper'

class MP3toHLSTest < Minitest::Test
  def setup
    @mp3hls = MP3toHLS.new

    # Create a tempory directory that files can be written to
    tempfile = Tempfile.new('mp3-to-hls-test')
    @testdir = tempfile.path
    tempfile.close!
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

  def test_create_output_dir
    assert(
      !File.exist?(@testdir),
      'Output dir should not exist before calling #create_output_dir'
    )
    @mp3hls.output_dir = @testdir
    @mp3hls.create_output_dir
    assert(
      File.exist?(@testdir),
      'Output dir should exist after calling #create_output_dir'
    )
  end

  def test_write_empty_manifest
    @mp3hls.output_dir = @testdir
    @mp3hls.create_output_dir
    @mp3hls.write_manifest

    assert File.exist?(@mp3hls.manifest_filepath), 'Manfest file should exist'

    lines = File.readlines(@mp3hls.manifest_filepath).map(&:strip)
    assert_equal 6, lines.count

    assert_equal '#EXTM3U', lines[0]
    assert_equal '#EXT-X-TARGETDURATION:10', lines[1]
    assert_equal '#EXT-X-VERSION:3', lines[2]
    assert_equal '#EXT-X-MEDIA-SEQUENCE:0', lines[3]
    assert_equal '#EXT-X-PLAYLIST-TYPE:VOD', lines[4]
    assert_equal '#EXT-X-ENDLIST', lines[5]
  end
end
