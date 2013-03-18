module Faye
  class RackStream

    include EventMachine::Deferrable
    READ_INTERVAL = 0.001

    module Reader
      attr_accessor :stream
      
      def receive_data(data)
        stream.receive(data)
      end
    end

    def initialize(socket_object)
      @socket_object = socket_object
      @connection    = socket_object.env['em.connection']
      @stream_send   = socket_object.env['stream.send']

      if socket_object.env['rack.hijack?']
        socket_object.env['rack.hijack'].call
        @rack_hijack_io = socket_object.env['rack.hijack_io']
        EventMachine.attach(@rack_hijack_io, Reader) { |r| r.stream = self }
      end

      @connection.socket_stream = self if @connection.respond_to?(:socket_stream)
    end

    def clean_rack_hijack
      return unless @rack_hijack_io
      @rack_hijack_io.close
      @rack_hijack_io = nil
    end

    def close_connection
      clean_rack_hijack
      @connection.close_connection if @connection
    end

    def close_connection_after_writing
      clean_rack_hijack
      @connection.close_connection_after_writing if @connection
    end

    def each(&callback)
      @stream_send ||= callback
    end

    def fail
      @socket_object.close
    end

    def receive(data)
    end

    def write(data)
      return @rack_hijack_io.write(data) if @rack_hijack_io
      return @stream_send.call(data) if @stream_send
    rescue => e
      fail if EOFError === e
    end

  end
end
