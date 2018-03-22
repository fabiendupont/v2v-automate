module ManageIQ
  module Automate
    module Transformation
      module TransformationHosts
        module OVirtHost
          class Utils        
            def initialize(handle = $evm)
              @handle = handle
            end
   
            def self.remote_command(host, command, stdin=nil, run_as=nil)
              require "net/ssh"
              command = "sudo -u #{run_as} #{command}" unless run_as.nil?
              success, stdout, stderr = true, '', ''
              Net::SSH.start(host.name, host.authentication_userid, :password => host.authentication_password) do |ssh|
                channel = ssh.open_channel do |channel|
                  channel.request_pty unless run_as.nil?
                  channel.exec(command) do |channel, success|
                    if success
                      channel.on_data do |_, data|
                        stdout += data.to_s
                      end
                      channel.on_extended_data do |_, data|
                        stderr += data.to_s
                      end
                      unless stdin.nil?
                        channel.send_data(stdin)
                        channel.eof!
                      end
                    else
                      success = false
                      stderr = "Could not execute command."
                    end
                  end
                end
                channel.wait
              end
              return { :success => success, :stdout => stdout, :stderr => stderr }
            end
          end
        end
      end
    end
  end
end
