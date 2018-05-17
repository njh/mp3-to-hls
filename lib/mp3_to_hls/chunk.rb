require 'taglib'

class MP3toHLS
  # A single chunk/file in the HLS stream
  class Chunk
    attr_accessor :number
    attr_accessor :samplerate
    attr_accessor :first_sample
    attr_accessor :frames
    attr_accessor :samples
    attr_accessor :data

    def initialize(chunk_number)
      @number = chunk_number
      @samplerate = nil
      @samples = 0
      @frames = 0
      @data = ''
    end

    def filename
      format('chunk_%6.6d.mp3', number)
    end

    def write(dir)
      filepath = File.join(dir, filename)
      puts "Creating: #{filepath}"

      File.open(filepath, 'wb') do |file|
        file.write data
      end

      # Save memory
      @data = nil

      write_timestamp_tag(filepath)
    end

    def duration
      samples.to_f / samplerate.to_f
    end

    def timestamp
      ((first_sample.to_f / samplerate) * 90_000.0).floor
    end

    def append_frame(frame, header)
      @samplerate ||= header.samplerate
      @data += frame
      @samples += header.samples
      @frames += 1
    end

    def write_timestamp_tag(filepath)
      TagLib::MPEG::File.open(filepath) do |file|
        tag = file.id3v2_tag(true)

        # Create a 'PRIV' frame
        priv = TagLib::ID3v2::PrivateFrame.new
        priv.data = [
          timestamp & 0x0100000000,
          timestamp & 0x00FFFFFFFF
        ].pack('NN')
        priv.owner = 'com.apple.streaming.transportStreamTimestamp'
        tag.add_frame(priv)

        file.save || raise('Failed to write ID3 tag')
      end
    end
  end
end
