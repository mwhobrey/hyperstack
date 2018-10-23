require 'hyperstack/hot_loader/add_error_boundry'
require 'hyperstack/hot_loader/stack-trace.js'
require 'hyperstack/hot_loader/css_reloader'
require 'opal-parser' # gives me 'eval', for hot-loading code

require 'json'
require 'hyperstack/hot_loader/short_cut.js'

# Opal client to support hot reloading
$eval_proc = proc do |file_name, s|
  $_hyperstack_reloader_file_name = file_name
  eval s
end

module Hyperstack

  class HotLoader
    def self.callbackmaps
      @@callbackmaps ||= Hash.new { |h, k| h[k] = Hash.new { |h1, k1| h1[k1] = Hash.new { |h2, k2| h2[k2] = Array.new }}}
    end

    def self.record(klass, instance_var, depth, *items)
      if $_hyperstack_reloader_file_name
        callbackmaps[$_hyperstack_reloader_file_name][klass][instance_var].concat items
      else
        callback = lambda do |stack_frames|
          file_name = `#{stack_frames[depth]}.fileName`
          match = /^(.+\/assets\/)(.+\/)\2/.match(file_name)
          if match
            file_name = file_name.gsub(match[1]+match[2], '')
            callbackmaps[file_name][klass][instance_var].concat items
          end
        end
        error = lambda do |err|
          `console.error(#{"hyperstack hot loader could not find source file for callback: #{err}"})`
        end
        `StackTrace.get().then(#{callback}).catch(#{error})`
       end
    end

    def self.remove(file_name)
      callbackmaps[file_name].each do |klass, instance_vars|
        instance_vars.each do |instance_var, items|
          klass.instance_variable_get(instance_var).reject! { |item| items.include? item }
        end
      end
    end

    def connect_to_websocket(port)
      host = `window.location.host`.sub(/:\d+/, '')
      host = '127.0.0.1' if host == ''
      protocol = `window.location.protocol` == 'https:' ? 'wss:' : 'ws:'
      ws_url = "#{host}:#{port}"
      puts "Hot-Reloader connecting to #{ws_url}"
      ws = `new WebSocket(#{protocol} + '//' + #{ws_url})`
      `#{ws}.onmessage = #{lambda { |e| reload(e) }}`
      `setInterval(function() { #{ws}.send('') }, #{@ping * 1000})` if @ping
    end

    def notify_error(reload_request)
      msg = "HotLoader #{reload_request[:filename]} RELOAD ERROR:\n\n#{$!}"
      puts msg
      alert msg if use_alert?
    end

    @@USE_ALERT = true
    def self.alerts_on!
      @@USE_ALERT = true
    end

    def self.alerts_off!
      @@USE_ALERT = false
    end

    def use_alert?
      @@USE_ALERT
    end

    def reload(e)
      reload_request = JSON.parse(`e.data`)
      if reload_request[:type] == "ruby"
        puts "Reloading #{reload_request[:filename]} (asset_path: #{reload_request[:asset_path]})"
        begin
          #Hyperstack::Context.reset! false
          file_name = reload_request[:asset_path] #.gsub(/.+hyperstack\//, '')
          HotLoader.remove(file_name)
          $eval_proc.call file_name, reload_request[:source_code]
        rescue
          notify_error(reload_request)
        end
        if @reload_post_callback
          @reload_post_callback.call
        else
          puts "no reloading callback to call"
        end
      end
      if reload_request[:type] == "css"
        @css_reloader.reload(reload_request, `document`)
      end
    end

    # @param port [Integer] opal hot reloader port to connect to
    # @param reload_post_callback [Proc] optional callback to be called after re evaluating a file for example in react.rb files we want to do a React::Component.force_update!
    def initialize(port=25222, ping=nil, &reload_post_callback)
      @port = port
      @reload_post_callback  = reload_post_callback
      @css_reloader = CssReloader.new
      @ping = ping
    end
    # Opens a websocket connection that evaluates new files and runs the optional @reload_post_callback
    def listen
      connect_to_websocket(@port)
    end

    def self.listen(port=25222, ping=nil)
      ::Hyperstack::Internal::Component::TopLevelRailsComponent.include AddErrorBoundry
      @server = HotLoader.new(port, ping) do
        # TODO: check this out when Operations are integrated
        # if defined?(Hyperloop::Internal::Operation::ClientDrivers) &&
        #    Hyperloop::ClientDrivers.respond_to?(:initialize_client_drivers_on_boot)
        #   Hyperloop::ClientDrivers.initialize_client_drivers_on_boot
        # end
        Hyperstack::Component.force_update!
      end
      @server.listen
    end

  end
end
