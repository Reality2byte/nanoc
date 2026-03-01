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
          # (If no focus is specified, `@focus` will be `nil`, not an empty
          # array.)
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

          selector.each do |rep|
            handle_errors_while(rep) do
              compile_rep(rep, outdated_reps:)
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

        def compile_rep(rep, outdated_reps:)
          Nanoc::Core::NotificationCenter.post(:compilation_started, rep)

          outdated = outdated_reps.include?(rep)
          if !outdated && @compiled_content_cache.full_cache_available?(rep)
            Nanoc::Core::NotificationCenter.post(:cached_content_used, rep)
            @compiled_content_repo.set_all(rep, @compiled_content_cache[rep])
            rep.compiled = true
          end

          unless rep.compiled?
            recalculate_rep(rep)
            @compiled_content_cache[rep] = @compiled_content_repo.get_all(rep)
            rep.compiled = true
          end

          if outdated
            # Caution: Notification must be posted before enqueueing the rep,
            # or we risk a race condition where the :rep_write_ended
            # notification happens before the :rep_write_enqueued one.
            Nanoc::Core::NotificationCenter.post(:rep_write_enqueued, rep)
            @writer.write_all(rep, @compiled_content_repo)
          end

          @outdatedness_store.remove(rep)

          Nanoc::Core::NotificationCenter.post(:compilation_ended, rep)
        rescue Nanoc::Core::Errors::UnmetDependency
          Nanoc::Core::NotificationCenter.post(:compilation_suspended, rep)
          raise
        end

        def recalculate_rep(rep)
          dependency_tracker = Nanoc::Core::DependencyTracker.new(
            @dependency_store, root: rep.item
          )

          executor = Nanoc::Core::Executor.new(
            rep, @compilation_context, dependency_tracker
          )

          # Set initial content, if not already present
          compiled_content_repo = @compilation_context.compiled_content_repo
          unless compiled_content_repo.get_current(rep)
            compiled_content_repo.set_current(rep, rep.item.content)
          end

          actions = pending_action_sequence_for(rep:)
          until actions.empty?
            action = actions.first

            case action
            when Nanoc::Core::ProcessingActions::Filter
              executor.filter(action.filter_name, action.params)
            when Nanoc::Core::ProcessingActions::Layout
              executor.layout(action.layout_identifier, action.params)
            when Nanoc::Core::ProcessingActions::Snapshot
              action.snapshot_names.each do |snapshot_name|
                executor.snapshot(snapshot_name)
              end
            else
              raise Nanoc::Core::Errors::InternalInconsistency,
                    "unknown action #{action.inspect}"
            end

            actions.shift
          end
        end

        def pending_action_sequence_for(rep:)
          @_pending_action_sequences ||= {}
          @_pending_action_sequences[rep] ||= @action_sequences[rep].to_a
        end
      end
    end
  end
end
