# frozen_string_literal: true

module Nanoc
  module Core
    module OutdatednessRules
      class LayoutAdded < Nanoc::Core::OutdatednessRule
        affects_props :raw_content

        contract Nanoc::Core::LayoutCollection,
                 C::Named['Nanoc::Core::BasicOutdatednessChecker'] =>
                 C::Maybe[Nanoc::Core::OutdatednessReasons::Generic]
        def apply(_obj, basic_outdatedness_checker)
          new_layouts = basic_outdatedness_checker.dependency_store.new_layouts
          if new_layouts.size.positive?
            Nanoc::Core::OutdatednessReasons::DocumentAdded.new(
              identifiers: new_layouts.map(&:identifier),
            )
          end
        end
      end
    end
  end
end
