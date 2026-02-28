# frozen_string_literal: true

module Nanoc
  module Core
    module OutdatednessRules
      class ItemAdded < Nanoc::Core::OutdatednessRule
        affects_props :raw_content

        contract Nanoc::Core::ItemCollection,
                 C::Named['Nanoc::Core::BasicOutdatednessChecker'] =>
                 C::Maybe[Nanoc::Core::OutdatednessReasons::Generic]
        def apply(_obj, basic_outdatedness_checker)
          new_items = basic_outdatedness_checker.dependency_store.new_items
          if new_items.size.positive?
            Nanoc::Core::OutdatednessReasons::DocumentAdded.new(
              identifiers: new_items.map(&:identifier),
            )
          end
        end
      end
    end
  end
end
