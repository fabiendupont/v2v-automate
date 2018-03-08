module ManageIQ
  module Automate
    module Transformation
      module Infrastructure
        module VM
          module RedHat
            class Import
              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                task = @handle.root['service_template_transformation_plan_task']
                source_vm = task.source

                destination_cluster = task.transformation_destination(source_vm.ems_cluster)
                destination_ems = destination_cluster.ext_management_system

                destination_storage = nil
                # FIXME: find the correct filter for disk eligibility
                #eligible_disks = source_vm.hardware.disks.select { |disk| disk.device_type == "disk" && disk.present && disk.start_connected }
                eligible_disks = source_vm.hardware.disks.select { |disk| disk.device_type == "disk" && disk.present }
                if eligible_disks.length == 1
                  destination_storage = task.transformation_destination(eligible_disks.first.storage)
                else
                  # Placeholder for more complex algorithm. Currently, using first disk.
                  destination_storage = task.transformation_destination(eligible_disks.first.storage)
                end

                ManageIQ::Automate::Transformation::Infrastructure::VM::RedHat::Utils.new(destination_ems).vm_import(source_vm.name, destination_cluster.name, destination_storage.name)
              end
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::Infrastructure::VM::RedHat::Import.new.main
end
