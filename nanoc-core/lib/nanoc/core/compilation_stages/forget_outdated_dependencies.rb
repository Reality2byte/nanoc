# frozen_string_literal: true

module Nanoc
  module Core
    module CompilationStages
      class ForgetOutdatedDependencies < Nanoc::Core::CompilationStage
        include Nanoc::Core::ContractsSupport

        def initialize(dependency_store:)
          super()

          @dependency_store = dependency_store
        end

        contract C::IterOf[Nanoc::Core::Item] => C::Any
        def run(outdated_items)
          outdated_items.each do |i|
            @dependency_store.forget_dependencies_for(i)
          end
        end
      end
    end
  end
end
