# frozen_string_literal: true

module Nanoc
  module Core
    module CompilationStages
      class CompileReps < Nanoc::Core::CompilationStage
        include Nanoc::Core::ContractsSupport
        include Nanoc::Core::Assertions::Mixin

        def initialize(
          reps:, outdatedness_store:, dependency_store:, action_sequences:,
          compilation_context:, compiled_content_cache:, focus:
        )
          super()

          @reps = reps
          @outdatedness_store = outdatedness_store
          @dependency_store = dependency_store
          @action_sequences = action_sequences
          @compilation_context = compilation_context
          @compiled_content_cache = compiled_content_cache
          @focus = focus

          @compiled_content_repo = @compilation_context.compiled_content_repo

          @writer = Nanoc::Core::ItemRepWriter.new
        end

        def run
          outdated_reps = @reps.select { |r| @outdatedness_store.include?(r) }

          # If a focus is specified, only compile reps that match this focus.
          # (If no focus is specified, `@focus` will be `nil`, not an empty array.)
          if @focus
            focus_patterns = @focus.map { |f| Nanoc::Core::Pattern.from(f) }

            # Find reps for which at least one focus pattern matches.
            outdated_reps = outdated_reps.select do |irep|
              focus_patterns.any? do |focus_pattern|
                focus_pattern.match?(irep.item.identifier)
              end
            end
          end

          selector = Nanoc::Core::ItemRepSelector.new(
            outdated_reps:,
            reps: @reps,
            dependency_store: @dependency_store,
          )

          phase_stack = build_phase_stack
          selector.each do |rep|
            handle_errors_while(rep) do
              compile_rep(rep, phase_stack:, is_outdated: @outdatedness_store.include?(rep))
            end
          end

          unless @focus
            assert Nanoc::Core::Assertions::AllItemRepsHaveCompiledContent.new(
              compiled_content_cache: @compiled_content_cache,
              item_reps: @reps,
            )
          end
        ensure
          @outdatedness_store.store
          @compiled_content_cache.prune(items: @reps.map(&:item).uniq)
          @compiled_content_cache.store
        end

        private

        def handle_errors_while(item_rep)
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          raise Nanoc::Core::Errors::CompilationError.new(e, item_rep)
        end

        def compile_rep(rep, phase_stack:, is_outdated:)
          Nanoc::Core::NotificationCenter.post(:compilation_started, rep)

          unless rep.compiled?
            phase_stack.call(rep, is_outdated:)

            @compiled_content_cache[rep] = @compiled_content_repo.get_all(rep)
            rep.compiled = true
          end

          # Caution: Notification must be posted before enqueueing the rep,
          # or we risk a race condition where the :rep_write_ended
          # notification happens before the :rep_write_enqueued one.
          Nanoc::Core::NotificationCenter.post(:rep_write_enqueued, rep)
          @writer.write_all(rep, @compiled_content_repo)

          @outdatedness_store.remove(rep)

          Nanoc::Core::NotificationCenter.post(:compilation_ended, rep)
        rescue Nanoc::Core::Errors::UnmetDependency
          Nanoc::Core::NotificationCenter.post(:compilation_suspended, rep)
          raise
        end

        def build_phase_stack
          Nanoc::Core::CompilationPhases::Recalculate.new(
            action_sequences: @action_sequences,
            dependency_store: @dependency_store,
            compilation_context: @compilation_context,
          )
        end
      end
    end
  end
end
