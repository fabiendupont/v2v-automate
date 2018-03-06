module ManageIQ
  module Automate
    module Transformation
      module TransformationHost
        module OVirtHost
          class VMCheckSyspreped_vmware2redhat_vddk
            def initialize(handle=$evm)
              @handle = handle
            end
        
            def main
              task = @handle.root['service_template_transformation_plan_task']
              source_vm = task.source
          
              if source_vm.platform == 'linux'
                factory_config = @handle.get_state_var(:factory_config)
                raise "No factory config found. Aborting." if factory_config.nil?
          
                # Get the virt-v2v start timestamp
                start_timestamp = task.get_option(:sysprep_started_on)

                # Retrieve transformation host
                transformation_host = @handle.vmdb(:host).find_by(:id => task.get_option(:transformation_host_id))
              
                # Setting directories and files path to track transformation
                base_directory = "/tmp/v2v_transformation"
                work_directory = "#{base_directory}/#{source_vm.name}"
                sysprep_log = "#{work_directory}/#{start_timestamp}-sysprep.log"

                result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "ps -aux | awk '{ print $2; }' | grep `cat #{work_directory}/sysprep.pid`")
                raise result[:stderr] unless result[:success]
                sysprep_process = result[:stdout]
                
                result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "cat #{sysprep_log}")
                raise result[:stderr] unless result[:success]
                sysprep_output = result[:stdout]

                if sysprep_process.empty?
                  task.set_option(:sysprep_finished_on, Time.now.strftime('%Y%m%d_%H%M'))
                  sysprep_success = sysprep_output.each_line.lazy.detect { |line| /error/i.match(line) }.nil?
                  if sysprep_success
                    task.set_option(:sysprep_status, 'success')
                  else
                    task.set_option(:sysprep_status, 'failure')
                  end
                  # Clean up the temporary files
                  result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "umount #{work_directory}/export_domain")
                  raise result[:stderr] unless result[:success]
                  #result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "rm -rf #{work_directory}")
                  #raise result[:stderr] unless result[:success]
                end
          
                if task.get_option(:sysprep_finished_on).nil?
                  @handle.log(:info, "Sysprep process: #{sysprep_process}")
                  @handle.log(:info, "Sysprep status: #{sysprep_process.empty?}")
                  @handle.root['ae_result'] = 'retry'
                  #@handle.root['ae_retry_server_affinity'] = true
                  @handle.root['ae_retry_interval'] = factory_config['check_convert_interval'] || '1.minutes'
                end
              end
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::TransformationHost::OVirtHost::VMCheckSyspreped_vmware2redhat_vddk.new.main
end
