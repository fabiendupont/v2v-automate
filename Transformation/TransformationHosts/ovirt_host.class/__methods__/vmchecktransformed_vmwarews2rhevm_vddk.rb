module ManageIQ
  module Automate
    module Transformation
      module TransformationHost
        module OVirtHost
          class VMCheckTransformed_vmware2redhat_vddk
            def initialize(handle = $evm)
              @debug = true
              @handle = handle
            end

            def main
              factory_config = @handle.get_state_var(:factory_config)
              raise "No factory config found. Aborting." if factory_config.nil?

              task = @handle.root['service_template_transformation_plan_task']
              source_vm = task.source

              # Get the virt-v2v start timestamp
              start_timestamp = task.get_option(:virtv2v_started_on)

              # Retrieve transformation host
              transformation_host = @handle.vmdb(:host).find_by(:id => task.get_option(:transformation_host_id))

              # Setting directories and files path to track transformation
              base_directory = "/tmp/v2v_transformation"
              work_directory = "#{base_directory}/#{source_vm.name}"
              virtv2v_log = "#{work_directory}/#{start_timestamp}-virtv2v.log"

              result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "ps -aux | awk '{ print $2; }' | grep \`cat #{work_directory}/virtv2v.pid\`")
              raise result[:stderr] unless result[:success]
              virtv2v_process = result[:stdout]

              result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "cat '#{virtv2v_log}'")
              raise result[:stderr] unless result[:success]
              virtv2v_output = result[:stdout]

              # Retrieve disks array
              disks = task.get_option(:virtv2v_disks)
              disks = [disks] if disks.is_a?(Hash)

              if virtv2v_process.empty?
                task.set_option(:virtv2v_finished_on, Time.now.strftime('%Y%m%d_%H%M'))
                virtv2v_status = virtv2v_output.lines.last
                virtv2v_success = virtv2v_status.strip.include?('Finishing off')
                if virtv2v_success
                  disks.each { |disk| disk[:percent] = 100 }
                  @handle.set_state_var(:ae_state_progress, { 'message' => 'Disks transformation succeeded.', 'percent' => 100 })
                else
                  @handle.set_state_var(:ae_state_progress, { 'message' => virtv2v_status })
                  raise "Disks transformation failed."
                end
              else
                disk_id = 0
                virtv2v_output.lines.each do |line|
                  if disks[disk_id][:path].nil?
                    next unless line.include?(' Copying disk ')
                    path = line.split(' ').pop(2).first.split('/').drop(3).join('/')
                    disks[disk_id][:path] = path
                  else
                    disks[disk_id][:percent] = line.split("\r").last.strip.gsub(/[\(\)]/, '').split('/').first
                    disk_id += 1
                  end
                end
                converted_disks = disks.select { |disk| not disk[:path].nil? }
                if converted_disks.empty?
                  @handle.set_state_var(:ae_state_progress, { 'message' => "Disks transformation is initializing.", 'percent' => 1 })
                else
                  disk_weight = 100.to_f / disks.length.to_f
                  percent = 0
                  converted_disks.each { |disk| percent += ( disk[:percent].to_f * disk_weight.to_f / 100.to_f ) }
                  message = "Converting disk #{converted_disks.length} / #{disks.length} [#{percent.round(2)}%]."
                  @handle.set_state_var(:ae_state_progress, { 'message' => message, 'percent' => percent.round(2) })
                end
              end

              task.set_option(:virtv2v_disks, disks)

              if task.get_option(:virtv2v_finished_on).nil?
                @handle.root['ae_result'] = 'retry'
                @handle.root['ae_retry_server_affinity'] = true
                @handle.root['ae_retry_interval'] = factory_config['vmtransformation_check_interval'] || '15.seconds'
              end
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::TransformationHost::OVirtHost::VMCheckTransformed_vmware2redhat_vddk.new.main
end
