module ManageIQ
  module Automate
    module Transformation
      module TransformationHost
        module OVirtHost
          class VMTransform_vmwarews2rhevm_vddk
            TRANSFORMATION_METHOD = "vddk".freeze
            DESTINATION_OUTPUT_TYPES = { 'openstack' => 'local', 'rhevm' => 'rhv' }.freeze
            DESTINATION_OUTPUT_FORMATS = { 'openstack' => 'raw', 'rhevm' => 'qcow2' }.freeze

            def initialize(handle = $evm)
              @debug = true
              @handle = handle
            end

            def main
              require 'json'
              
              factory_config = @handle.get_state_var(:factory_config)
              raise "No factory config found. Aborting." if factory_config.nil?

              task = @handle.root['service_template_transformation_plan_task']
              source_vm = task.source
              source_cluster = source_vm.ems_cluster
              source_ems = source_vm.ext_management_system
              destination_ems = task.transformation_destination(source_cluster).ext_management_system
              raise "Invalid destination EMS type: #{destination_ems.emstype}. Aborting." unless destination_ems.emstype == "rhevm"

              # Get or create the virt-v2v start timestamp
              start_timestamp = task.get_option(:virtv2v_started_on) || Time.now.strftime('%Y-%m-%d %H:%M:%S')

              # Retrieve transformation host
              transformation_host = @handle.vmdb(:host).find_by(:id => task.get_option(:transformation_host_id))

              @handle.log(:info, "Transformation - Started On: #{start_timestamp}")

              max_runners = destination_ems.custom_get('Max Transformation Runners') || factory_config['max_transformation_runners_by_ems'] || 1
              if Transformation::TransformationHosts::Common::Utils.get_runners_count_by_ems(destination_ems, @handle.get_state_var(:transformation_method), factory_config) >= max_runners
                @handle.log("Too many transformations running: (#{max_runners}). Retrying.")
              else
                # Identify the RHV export domain
                export_domain = destination_ems.storages.select { |s| s.storage_domain_type == 'export' }.first
                task.set_option(:export_domain_id, export_domain.id)

                # Collect the VMware connection information
                vmware_uri = "vpx://"
                vmware_uri += "#{source_ems.authentication_userid.gsub('@', '%40')}@#{source_ems.hostname}/"
                vmware_uri += "#{source_cluster.v_parent_datacenter.gsub(' ', '%20')}/#{source_cluster.name.gsub(' ', '%20')}/#{source_vm.host.uid_ems}"
                vmware_uri += "?no_verify=1"

                # Collect information about the disks to convert
                virtv2v_disks = []
                source_disks = []
                source_vm.hardware.disks.select { |d| d.device_type == 'disk' }.each do |disk|
                  virtv2v_disks << { path: disk.filename, size: disk.size, percent: 0, weight: disk.size / source_vm.allocated_disk_storage * 100 }
                  source_disks << disk.filename
                end
                @handle.log(:info, "Source VM Disks #{virtv2v_disks}")

                wrapper_options = {
                  transport_method: 'vddk',
                  export_domain: export_domain.location,
                  vm_name: source_vm.name,
                  vmware_fingerprint: Transformation::Infrastructure::VM::VMware::Utils.get_vcenter_fingerprint(source_ems),
                  vmware_uri: vmware_uri,
                  vmware_password: source_ems.authentication_password,
                  source_disks: source_disks
                }
                
                @handle.log(:info, "Connecting to #{transformation_host.name} as #{transformation_host.authentication_userid}") if @debug
                @handle.log(:info, "Executing '/usr/bin/virt-v2v-wrapper.py'")
                result = Transformation::TransformationHosts::OVirtHost::Utils.remote_command(transformation_host, "/usr/bin/virt-v2v-wrapper.py", stdin = wrapper_options.to_json)
                raise result[:stderr] unless result[:success]

                # Record the wrapper files path
                @handle.log(:info, "Command stdout: #{result[:stdout]}")
                task.set_option(:virtv2v_wrapper, JSON.parse(result[:stdout]))
                
                # Record the status in the task object
                task.set_option(:virtv2v_started_on, start_timestamp)
                task.set_option(:virtv2v_status, 'active')
                task.set_option(:virtv2v_disks, virtv2v_disks)
              end

              if task.get_option(:virtv2v_started_on).nil?
                @handle.root['ae_result'] = 'retry'
                @handle.root['ae_retry_server_affinity'] = true
                @handle.root['ae_retry_interval'] = $evm.object['check_convert_interval'] || '1.minutes'
              end
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::TransformationHost::OVirtHost::VMTransform_vmwarews2rhevm_vddk.new.main
end
