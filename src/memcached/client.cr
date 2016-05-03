module Memcached
  class Client
    @host : String
    @port : Int32
    @read_timeout : Float64?
    @write_timeout : Float64?
    @socket : TCPSocket

    # Opens connection to Memcached server
    #
    # **Options**
    # * host : String - memcached host
    # * port : Number - memcached port
    def initialize(@host = "localhost", @port = 11211, @read_timeout = nil, @write_timeout = nil)
      Memcached.logger.info("Connecting to #{host}:#{port}")
      @socket = TCPSocket.new(host, port)
      @socket.read_timeout = @read_timeout
      @socket.write_timeout = @write_timeout
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

    # Append a value to a key
    def append(key : String, value : String, ttl : Number = 0, flags : Number = 0)
      store("append", key, value, ttl, flags)
    end

    # Prepend a value to a key
    def prepend(key : String, value : String, ttl : Number = 0, flags : Number = 0)
      store("prepend", key, value, ttl, flags)
    end

    # Increment key by value
    def incr(key : String, value : Number = 1)
      incdec("incr", key, value)
    end

    # Decrement key by value
    def decr(key : String, value : Number = 1)
      incdec("decr", key, value)
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

    private def incdec(op : String, key : String, value : Number) : Int64
      write("#{op} #{key} #{value}\r\n")

      line = @socket.gets('\n')
      if line.nil?
        raise EOFError.new("EOF reached")
      end

      if line == "NOT_FOUND\r\n"
        Memcached.logger.info("#{op} miss: #{key}")
        begin
          initial_value = (op == "incr" ? 1 : -1).to_i64 * value
          add(key, initial_value.to_s)
          initial_value
        rescue e : NotStoredError
          Memcached.logger.info("IncDec: Race condition setting initial value for #{key}")
          # retry whole operation
          incdec(op, key, value)
        end
      else
        line.strip.to_i64
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
