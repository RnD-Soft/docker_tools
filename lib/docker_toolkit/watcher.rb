#!/usr/bin/env ruby
require 'English'

module DockerToolkit

  class Watcher


    def initialize
      @lock = Mutex.new

      @procs = []
      @code = 0
      @crashed = false
      @threads = []
      @who = nil
      @stopping = false
      end

    def stop_all
      @stopping = true

      terminating = @procs.reject do |meta|
        meta[:handled] || meta[:process].exited?
      end

      terminating.each do |meta|
        ::Process.kill 'TERM', meta[:process].pid
      end

      terminating.each do |meta|
        begin
          meta[:process].poll_for_exit(10)
        rescue ChildProcess::TimeoutError
          meta[:process].stop(1)
          meta[:stdout].close
          meta[:stderr].close
        end
      end

      unless @crashed
        meta = @procs.detect do |meta|
          meta[:process].crashed?
        end

        if meta
          @crashed = true
          @code = meta[:process].exit_code
          @who = meta[:cmd]
        end
      end

      @procs.each do |meta|
        begin
        meta[:stdout].close
      rescue StandardError
        nil
      end
        begin
        meta[:stderr].close
      rescue StandardError
        nil
      end
      end

      Thread.new do
        sleep 2
        @threads.each(&:terminate)
      end
        end

    def add(*cmd)
      process = ChildProcess.build(*cmd)

      rerr, werr = IO.pipe
      rout, wout = IO.pipe

      process.io.stdout = wout
      process.io.stderr = werr

      meta = {
        cmd: cmd,
        process: process,
        stdout: rout,
        stderr: rerr
      }

      @threads << Thread.new(meta[:stdout], STDOUT) do |io, out|
        loop do
          break unless synchro_readline(io, out)
        end
      end

      @threads << Thread.new(meta[:stderr], STDERR) do |io, out|
        loop do
          break unless synchro_readline(io, out)
        end
      end

      log "Starting #{meta[:cmd]}"
      meta[:pid] = meta[:process].start.pid

      @procs.push(meta)
      meta
    end

    def synchro_readline(io, out)
      str = io.gets
      @lock.synchronize{ out.puts str }
      true
    rescue StandardError => e
      false
    end

    def log(msg)
      puts "[watcher]: #{msg}"
    end

    def error(msg)
      STDERR.puts "[watcher]: Error: #{msg}"
    end

    def exec
      %w[EXIT QUIT].each do |sig|
        trap(sig) do
          stop_all
        end
      end


      %w[INT TERM].each do |sig|
        trap(sig) do
          log "Catch #{sig}: try exits gracefully.."
          stop_all
        end
      end

      trap('CLD') do |*_args|
        unhandled = @procs.reject do |meta|
          meta[:handled] || !meta[:process].exited?
        end

        unhandled.any? do |meta|
          log 'Child finished'
          log "  Process[#{meta[:pid]}]: #{meta[:cmd]}"
          log "    status: #{meta[:process].crashed? ? 'crashed' : 'exited'}"
          log "    code:   #{meta[:process].exit_code}"

          meta[:handled] = true
          begin
          meta[:stdout].close
        rescue StandardError
          IOError
        end
          begin
          meta[:stderr].close
        rescue StandardError
          IOError
        end

          if !@crashed && meta[:process].crashed?
            @crashed = true
            @code = meta[:process].exit_code
            @who = meta[:cmd]
          end

          unless @stopping
            log 'Try exits gracefully..'
            stop_all
          end

          true
        end
      end

      begin
        yield(self)
      rescue StandardError => e
        @crashed = true
        @code = 1
        error e.inspect
        error e.backtrace.last(20).join("\n")
        log 'Try exits gracefully..'
        stop_all
      end

      @threads.map(&:join)

      @code = [@code || 0, 1].max if @crashed

      exit(@code || 0)
    end



  end

end
