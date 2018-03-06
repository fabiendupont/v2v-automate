module ManageIQ
  module Automate
    module Transformation
      module StateMachines
        module ShutDown
          class CheckOff
            def initialize(handle=$evm)
              @handle = handle
            end
            
            def main
			  vm = @handle.root['service_template_transformation_plan_task'].source
			  @handle.root['ae_result'] = 'skip' if vm.power_state == 'off'
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::StateMachines::Shutdown::CheckOff.new.main
end
