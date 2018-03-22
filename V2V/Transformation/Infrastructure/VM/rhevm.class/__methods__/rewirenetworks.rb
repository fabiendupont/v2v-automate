module ManageIQ
  module Automate
    module Transformation
      module Infrastructure
        module VM
          module RedHat
            class RewireNetworks
              def initialize(handle = $evm)
                @handle = handle
              end
          
              def main
                task = @handle.root['service_template_transformation_plan_task']
                source_vm = task.source
                destination_vm = @handle.vmdb(:vm).find_by(:id => task.get_option(:destination_vm_id))
                destination_ems = destination_vm.ext_management_system

                source_vm.hardware.nics.each do |source_nic|
                  destination_nic = destination_vm.hardware.nics.select { |nic| nic.address == source_nic.address }.first
                  destination_network = task.transformation_destination(source_nic.lan)
                  ManageIQ::Automate::Transformation::Infrastructure::VM::RedHat::Utils.new(destination_ems).vm_set_nic_network(destination_vm, destination_nic, destination_network)
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
  ManageIQ::Automate::Transformation::Infrastructure::VM::RedHat::RewireNetworks.new.main
end
