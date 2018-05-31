require 'mp3file'

require 'mp3_to_hls/chunk'
require 'mp3_to_hls/version'

# Convert an MP3 file into an HLS stream
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
    @total_duration = 0.0
    @chunks = []
  end

  def create_output_dir
    if !File.exist?(output_dir)
      Dir.mkdir(output_dir)
    elsif !File.directory?(output_dir)
      raise 'Output path exists but it is not a directory'
    end
  end

  def open_input_file
    @mp3file = Mp3file::MP3File.new(input_filename)
    @samples_per_chunk = target_chunk_duration * @mp3file.samplerate
    @frames_per_chunk = @samples_per_chunk / @mp3file.first_header.samples

    puts "Mode: #{@mp3file.mode}"
    puts "Bit Rate: #{@mp3file.bitrate} kpbs"
    puts "Sample Rate: #{@mp3file.samplerate} Hz"
    puts "Target Chunk Duration: #{target_chunk_duration} secs"
    puts "Frames per Chunk: #{@frames_per_chunk}"
    puts

    @input_file = File.open(@mp3file.file.path, 'rb')
    offset = @mp3file.first_header_offset

    @input_file.seek(offset, IO::SEEK_SET)
    header = Mp3file::MP3Header.new(@input_file)

    # Skip over the Xing header
    @input_file.seek(header.side_bytes, IO::SEEK_CUR)
    xing_magic = @input_file.read(4)
    offset += header.frame_size if xing_magic =~ /Xing|Info/

    @input_file.seek(offset, IO::SEEK_SET)
  end

  def new_chunk
    chunk = MP3toHLS::Chunk.new(@chunks.count)
    chunk.start_time = @total_duration
    @chunks << chunk
  end

  def write_chunks
    new_chunk

    offset = @input_file.tell
    until @input_file.eof?
      # Read in the header
      begin
        header = Mp3file::MP3Header.new(@input_file)
      rescue Mp3file::InvalidMP3HeaderError
        break
      end

      # Go back to the start of the frame and read it in
      @input_file.seek(offset, IO::SEEK_SET)
      frame = @input_file.read(header.frame_size)
      @chunks.last.append_frame(frame, header.duration)
      offset += header.frame_size

      # Do we have enough frames?
      next if @chunks.last.frames < @frames_per_chunk
      @chunks.last.write(@output_dir)
      @total_duration += @chunks.last.duration
      new_chunk
    end

    # Write out the final chunk
    @chunks.last.write(@output_dir) unless @chunks.last.frames.zero?
  end

  def close_input_file
    @input_file.close
  end

  def manifest_filepath
    File.join(output_dir, manifest_filename)
  end

  def write_manifest
    File.open(manifest_filepath, 'wb') do |file|
      file.puts '#EXTM3U'
      file.puts "#EXT-X-TARGETDURATION:#{target_chunk_duration.ceil}"
      file.puts '#EXT-X-VERSION:3'
      file.puts '#EXT-X-MEDIA-SEQUENCE:0'
      file.puts '#EXT-X-PLAYLIST-TYPE:VOD'

      @chunks.each do |chunk|
        file.puts "#EXTINF:#{chunk.duration}"
        file.puts chunk.filename
      end

      file.puts '#EXT-X-ENDLIST'
    end
  end

  def run
    create_output_dir
    open_input_file
    write_chunks
    close_input_file
    write_manifest
  end
end
