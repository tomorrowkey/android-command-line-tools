require 'thor'
require 'device_api/android'
require 'peco_selector'
require 'find'

module Android
  module Command
    module Line
      module Tools
        class CLI < Thor
          desc 'uninstall', 'Uninstall an application'
          def uninstall
            return (puts 'device not connected') unless device

            packages = list_installed_packages(device)
            package = select_installed_package(packages)
            execute_with_serial('adb', device, "uninstall -r #{file}")
          end

          desc 'install', 'Install an application'
          def install
            return (puts 'device not connected') unless device

            files = list_apk_files
            return (puts 'apk file not found') if files.empty?

            file = PecoSelector.select_from(files).first
            execute_with_serial('adb', device, "install -r #{file}")
          end

          desc 'clear', 'Clear apps data'
          def clear
            return (puts 'device not connected') unless device

            packages = list_installed_packages(device)
            package = select_installed_package(packages)
            execute_with_serial('adb', device, "shell pm clear #{package}")
          end

          desc 'screenshot', 'Take a screenshot'
          def screenshot
            return (puts 'device not connected') unless device

            outfile = "#{ENV['HOME']}/Desktop/screenshot_#{timestamp}.png"
            execute_with_serial('screenshot2', device, outfile)
            execute("open #{outfile}")
          end

          # ffmpeg -y -i movie.mp4 -vf scale=360:-1 -r 12 movie_360.mp4
          # ffmpeg -i movie_360.mp4 -vf palettegen=max_colors=256 palette.png
          # ffmpeg -i movie_360.mp4 -i palette.png -f gif -filter_complex paletteuse movie.gif
          desc 'screenrecord', 'Take a screenrecord'
          def screenrecord
            return (puts 'device not connected') unless device

            device_movie_path = "/sdcard/Download/movie_#{timestamp}.mp4"
            begin
              execute_with_serial('adb', device, "shell screenrecord #{device_movie_path}")
            rescue Interrupt
            end

            movie_path = Tempfile.new('movie_original').path + 'mp4'
            execute_with_serial('adb', device, "pull #{device_movie_path} #{movie_path}")

            resized_path = Tempfile.new('movie_resized').path + '.mp4'
            execute("ffmpeg -y -i #{movie_path} -vf scale=360:-1 -r 12 -f mp4 #{resized_path}")
            palette_path = Tempfile.new('movie_palette').path + '.png'
            execute("ffmpeg -i #{resized_path} -vf palettegen=max_colors=256 #{palette_path}")
            movie_path = "#{ENV['HOME']}/Desktop/movie_#{timestamp}.gif"
            execute("ffmpeg -i #{resized_path} -i #{palette_path} -f gif -filter_complex paletteuse #{movie_path}")

            execute("open #{movie_path}")
          end

          private
          def execute_with_serial(command, device, options)
            serial_option = device.nil? ? '' : "-s #{device.serial}"
            execute("#{command} #{serial_option} #{options}")
          end

          def execute(command)
            puts "+ #{command}"
            system command
          end

          def device
            return @device if @device

            devices = DeviceAPI::Android.devices
            return devices.first if devices.size <= 1

            @device ||= PecoSelector.select_from(devices.map{|device|
              ["#{device.model} (#{device.serial})", device]
            }).first
          end

          def list_installed_packages(device)
            device.list_installed_packages.map{|p| p.gsub('package:', '')}
          end

          def select_installed_package(packages)
            PecoSelector.select_from(packages).first
          end

          def list_apk_files
            Find.find(Dir.pwd).to_a.select{|f| f =~ /\.apk$/}
          end

          def timestamp
            Time.now.strftime('%Y%m%d%H%M%S')
          end
        end
      end
    end
  end
end
