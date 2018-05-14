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
    @total_samples = 0
    @chunks = []
  end

  def create_output_dir
    if !File.exist?(output_dir)
      Dir.mkdir(output_dir)
    elsif !File.directory?(output_dir)
      raise 'Output path exists but it is not a directory'
    end
  end

  def new_chunk
    chunk = MP3toHLS::Chunk.new(@chunks.count)
    chunk.first_sample = @total_samples
    @chunks << chunk
  end

  def write_chunks
    mp3file = Mp3file::MP3File.new(input_filename)
    puts "Mode: #{mp3file.mode}"
    puts "Bit Rate: #{mp3file.bitrate} kpbs"
    puts "Sample Rate: #{mp3file.samplerate} Hz"
    target_samples = target_chunk_duration * mp3file.samplerate
    puts "Target Samples per chunk: #{target_samples}"
    puts

    new_chunk

    File.open(mp3file.file.path, 'rb') do |file|
      offset = mp3file.first_header_offset

      file.seek(offset, IO::SEEK_SET)
      until file.eof?
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
        if @chunks.last.samples + header.samples > target_samples
          @chunks.last.write(@output_dir)
          @total_samples += @chunks.last.samples
          new_chunk
        end

        @chunks.last.append_audio(frame, header)
        offset += header.frame_size
      end
    end

    if @chunks.last.samples > 0
      # Write out a final chunk
      @chunks.last.write(@output_dir)
    end
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
    write_chunks
    write_manifest
  end
end
