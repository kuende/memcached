module Memcached
  class Client
    @socket : TCPSocket

    # Opens connection to Memcached server
    #
    # **Options**
    # * host : String - memcached host
    # * port : Number - memcached port
    def initialize(host = "localhost", port = 11211)
      Memcached.logger.info("Connecting to #{host}:#{port}")
      @socket = TCPSocket.new(host, port)
    end

    # Close the socket connection
    def close
      @socket.try &.close
    end

    # Get a single key value from memcached
    def get(key : String) : String?
      write("get #{key}\r\n")

      response = read_response
      if response.nil?
        Memcached.logger.info("Cache miss: #{key}")
      else
        Memcached.logger.info("Cache hit: #{key}")
      end

      response
    end

    # Gets multiple key-value pairs
    def get_multi(keys : Array(String)) : Hash(String, String?)
      results = {} of String => String?

      keys.each do |key|
        results[key] = get(key)
      end

      results
    end

    # Set a key - value pair
    #
    # **Options**
    # * keys : String - key
    # * value : String - value
    # * ttl : Number - if provided, expire the key after <ttl> seconds
    # * version : Number - if provided, checks if latest version is <version>
    # if versions differ, *Memcached::BadVersionException* will be raised
    def set(key : String, value : String, ttl : Number = 0, flags : Number = 0)
      store("set", key, value, ttl, flags)
      Memcached.logger.info("Cache set: #{key}")
    end

    # flush deletes all keys from memcached
    def flush
      write("flush_all\r\n")

      line = @socket.gets('\n')
      if line.nil?
        raise EOFError.new("EOF reached")
      elsif line != "OK\r\n"
        raise FlushError.new("Expected OK, got: #{line}")
      end
    end

    # Similar to set, it fails if key already exists
    def add(key : String, value : String, ttl : Number = 0, flags : Number = 0)
      store("add", key, value, ttl, flags)
      Memcached.logger.info("Cache add: #{key}")
    end

    # Delete a key from Memcached
    def delete(key : String) : Bool
      write("delete #{key}\r\n")

      line = @socket.gets('\n')
      if line.nil?
        raise EOFError.new("EOF reached")
      elsif line == "NOT_FOUND\r\n"
        return false
      elsif line != "DELETED\r\n"
        raise DeleteError.new("Expected DELETED, got: #{line}")
      end
      true
    end

    private def write(value : String)
      bytes = value.bytes
      @socket.write(Slice(UInt8).new(bytes.to_unsafe, bytes.size))
    end

    private def store(op : String, key : String, value : String, ttl : Number, flags : Number)
      write("#{op} #{key} #{flags} #{ttl} #{value.bytesize}\r\n")
      write(value)
      write("\r\n")
      @socket.flush

      line = @socket.gets('\n')
      if line.nil?
        raise EOFError.new("EOF reached")
      end

      if line == "NOT_STORED\r\n"
        raise NotStoredError.new("Value not stored, precondition failed")
      elsif line != "STORED\r\n"
        raise WriteError.new("Expected STORED, found: #{line}")
      end
    end

    private def read_response
      line = @socket.gets('\n')
      if line.nil?
        raise EOFError.new("Failed to read line, end of buffer reached")
      end

      a = line.strip.split(" ")
      if a.size != 4 || a[0] != "VALUE"
        if line == "END\r\n"
          return nil
        else
          raise ReadError.new("Invalid line: #{line}")
        end
      end

      flags = a[2].to_i
      length = a[3].to_i

      bytes_read = 0
      value = String.build do |s|
        loop do
          i = @socket.gets(length)

          if i.nil?
            raise EOFError.new("End of file reached")
          end

          s << i
          bytes_read += i.bytesize

          if bytes_read >= length
            break
          end
        end
      end

      line = @socket.gets('\n')
      if line.nil?
        raise ReadError.new("Expected to read newline, EOF reached")
      elsif line != "\r\n"
        raise ReadError.new("Expected \r\n, got: #{line}")
      end

      line = @socket.gets('\n')
      if line.nil?
        raise ReadError.new("Expected to read END, EOF reached")
      elsif line != "END\r\n"
        raise ReadError.new("Expected END\r\n, got: #{line}")
      end

      value
    end
  end
end
