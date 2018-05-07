require 'mp3file'
require 'taglib'

require 'mp3_to_hls/version'

class MP3toHLS
  attr_accessor :input_filename
  attr_accessor :manifest_filename
  attr_accessor :output_dir
  attr_accessor :target_chunk_duration

  DEFAULT_TARGET_LENGTH = 10
  DEFAULT_MANIFEST_FILENAME = 'index.m3u8'

  def initialize
    @target_chunk_duration = DEFAULT_TARGET_LENGTH
    @manifest_filename = DEFAULT_MANIFEST_FILENAME
    @chunks = []
  end

  def create_output_dir
    if !File.exist?(output_dir)
      Dir.mkdir(output_dir)
    elsif !File.directory?(output_dir)
      raise 'Output path exists but it is not a directory'
    end
  end

  def write_timestamp_tag(filename, ts)
    TagLib::MPEG::File.open(filename) do |file|
      tag = file.id3v2_tag(create = true)

      # Create a 'PRIV' frame
      priv = TagLib::ID3v2::PrivateFrame.new
      priv.data = [ts & 0x0100000000, ts & 0xFFFFFFFF].pack('NN')
      priv.owner = 'com.apple.streaming.transportStreamTimestamp'
      tag.add_frame(priv)

      file.save or raise 'Failed to write ID3 tag'
    end
  end

  def write_chunk(chunk_data, sample_count, start_time, chunk_number)
    filename = File.join(output_dir, sprintf('chunk_%6.6d.mp3', chunk_number))
    puts "Creating: #{filename}"

    File.open(filename, 'wb') do |file|
      file.write chunk_data
    end

    write_timestamp_tag(filename, (start_time * 90000.0).floor)

    {:filename => filename, :start_time => start_time, :duration => sample_count}
  end

  def write_chunks
    mp3file = Mp3file::MP3File.new(input_filename)
    puts "Mode: #{mp3file.mode}"
    puts "Bit Rate: #{mp3file.bitrate} kpbs"
    puts "Sample Rate: #{mp3file.samplerate} Hz"
    target_samples = target_chunk_duration * mp3file.samplerate
    puts "Target Samples per chunk: #{target_samples}"
    puts


    chunk_data = ''
    chunk_sample_count = 0
    total_samples = 0

    File.open(mp3file.file.path, 'rb') do |file|
      offset = mp3file.first_header_offset

      file.seek(offset, IO::SEEK_SET)
      while !file.eof?
        # Read in the header
        begin
          header = Mp3file::MP3Header.new(file)
        rescue InvalidMP3HeaderError
          break
        end

        # Skip over the Xing header
        file.seek(header.side_bytes, IO::SEEK_CUR)
        xing_magic = file.read(4)
        if xing_magic =~ /Xing|Info/
          offset += header.frame_size
          file.seek(offset, IO::SEEK_SET)
          next
        end

        # Go back to the start of the frame
        file.seek(offset, IO::SEEK_SET)
        frame = file.read(header.frame_size)

        # Will this frame take us over the target number of samples?
        if chunk_sample_count + header.samples > target_samples
          @chunks << write_chunk(
            chunk_data,
            chunk_sample_count,
            total_samples.to_f / mp3file.samplerate,
            @chunks.count
          )
          total_samples += chunk_sample_count
          chunk_data = ''
          chunk_sample_count = 0
        end

        chunk_data += frame
        chunk_sample_count += header.samples
        offset += header.frame_size
      end

    end

    if chunk_sample_count > 0
      # Write out a final chunk
      @chunks << write_chunk(
        chunk_data,
        chunk_sample_count,
        total_samples.to_f / mp3file.samplerate,
        @chunks.count
      )
    end
  end

  def write_manifest
    # Now create the HLS manifest file
    manifest_filepath = File.join(output_dir, manifest_filename)
    File.open(manifest_filepath, 'wb') do |file|
      file.puts '#EXTM3U'
      file.puts "#EXT-X-TARGETDURATION:#{target_chunk_duration.ceil}"
      file.puts '#EXT-X-VERSION:3'
      file.puts '#EXT-X-MEDIA-SEQUENCE:0'
      file.puts '#EXT-X-PLAYLIST-TYPE:VOD'

      @chunks.each do |chunk|
        file.puts "#EXTINF:#{chunk[:duration]}"
        file.puts File.basename(chunk[:filename])
      end

      file.puts '#EXT-X-ENDLIST'
    end
  end

  def run
    create_output_dir
    write_chunks
    write_manifest
  end
end
