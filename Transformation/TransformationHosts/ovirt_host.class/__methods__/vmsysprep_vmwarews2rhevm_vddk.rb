module ManageIQ
  module Automate
    module Transformation
      module TransformationHost
        module OVirtHost
          class VMSysprep_vmware2redhat_vddk
            def initialize(handle=$evm)
              @handle = handle
            end
        
            def main
              task = @handle.root['service_template_transformation_plan_task']
              source_vm = task.source
          
              if source_vm.platform == 'linux' and task.get_option(:virtv2v_disks).present?
                factory_config = @handle.get_state_var(:factory_config)
                raise "No factory config found. Aborting." if factory_config.nil?
          
                # Create the virt-v2v start timestamp
                start_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
                @handle.log(:info, "Transformation - Started On: #{task.get_option(:sysprep_started_on)}")

                # Retrieve transformation host
                transformation_host = @handle.vmdb(:host).find_by(:id => task.get_option(:transformation_host_id))
              
                # Retrieve disks array
                disks = task.get_option(:virtv2v_disks)
                disks = [disks] if disks.is_a?(Hash)
                @handle.log(:info, "Disks - #{disks.inspect}")

                # Setting directories and files path to track transformation
                base_directory = "/tmp/v2v_transformation"
                work_directory = "#{base_directory}/#{source_vm.name}"
                sysprep_log = "#{work_directory}/#{start_timestamp}-sysprep.log"
                
                # Mount the export domain if it is not mounted yet
                export_domain = @handle.vmdb(:storage).find_by(:id => task.get_option(:export_domain_id))
                mount_path = "#{work_directory}/export_domain"
                mount_command = "mkdir #{mount_path} ; mount -t #{export_domain.store_type.downcase} #{export_domain.location} #{mount_path}"
                result = ManageIQ::Automate::Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, mount_command)
                raise result[:stderr] unless result[:success]
 
                # Trigger sysprep on all disks
                command = "export LIBGUESTFS_BACKEND=direct"
                command += " ; nohup /usr/bin/virt-sysprep --enable net-hwaddr,udev-persistent-net,customize"
                @handle.log(:info, "Disks to sysprep:")
                disks.each { |disk| @handle.log(:info, " - #{disk.inspect}") }
                disks.each { |disk| command += " -a #{mount_path}/#{disk[:path]}" }
                command += " > '#{sysprep_log}' 2>&1 < /dev/null &"
                command += " echo $! > #{work_directory}/sysprep.pid"

                @handle.log(:info, "Connecting to #{transformation_host.name} as #{transformation_host.authentication_userid}") if @debug
                @handle.log(:info, "Executing : #{command}")
                result = ManageIQ::Automate::Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, command)
                raise result[:stderr] unless result[:success]

                # Record the status in the task object
                task.set_option(:sysprep_started_on, start_timestamp)
                task.set_option(:sysprep_status, 'active')
              else
                @handle.log(:info, "VM #{source_vm.name} is not running Linux or has no disk. Skipping.")
              end
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::TransformationHost::OVirtHost::VMSysprep_vmware2redhat_vddk.new.main
end
