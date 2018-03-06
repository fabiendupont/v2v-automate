module ManageIQ
  module Automate
    module Transformation
      module StateMachines
        module ShutDown
          class ShutdownVM
            def initialize(handle=$evm)
              @handle = handle
            end
            
            def main
              vm = @handle.root['service_template_transformation_plan_task'].source
              if @handle.state_var_exist?(:shutdown_attempted)
                vm.stop if @handle.root['ae_state_retries'] > @handle.object['minutes_to_shutdown']
              else
                vm.shutdown_guest
                @handle.set_state_var(:shutdown_attempted, true)
              end
              @handle.root['ae_result'] = 'retry'
              @handle.root['ae_retry_interval'] = '1.minute'
            end
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ManageIQ::Automate::Transformation::StateMachines::Shutdown::ShutdownVM.new.main
end
