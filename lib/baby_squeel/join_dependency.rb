require 'join_dependency'

module BabySqueel
  module JoinDependency
    # This class allows BabySqueel to slip custom
    # joins_values into Active Record's JoinDependency
    class Injector < Array # :nodoc:
      # Active Record will call group_by on this object
      # in ActiveRecord::QueryMethods#build_joins. This
      # allows BabySqueel::Joins to be treated
      # like typical join hashes until Polyamorous can
      # deal with them.
      def group_by
        super do |join|
          case join
          when BabySqueel::Join
            :association_join
          else
            yield join
          end
        end
      end
    end

    class Builder # :nodoc:
      attr_reader :join_dependency

      def initialize(relation)
        @join_dependency = ::JoinDependency.from_relation(relation) do |join|
          :association_join if join.kind_of? BabySqueel::Join
        end
      end

      # Find the alias of a BabySqueel::Association, by passing
      # a list (in order of chaining) of associations and finding
      # the respective JoinAssociation at each level.
      def find_alias(associations)
        join_association = find_join_association(associations)

        # NOTE: Below is a hack. It does not work. In previous
        # versions of Active Record, `#table` would ALWAYS return
        # an instance of Arel::Table.
        if join_association.table
          join_association.table
        else
          # This literally does not work. This will often
          # give you the wrong Arel::Table instance, which
          # causes aliases in the query to be wrong.
          join_association.base_klass.arel_table
        end
      end

      private

      def find_join_association(associations)
        associations.inject(join_dependency.send(:join_root)) do |parent, assoc|
          parent.children.find do |join_association|
            reflections_equal?(
              assoc._reflection,
              join_association.reflection
            )
          end
        end
      end

      # Compare two reflections and see if they're the same.
      def reflections_equal?(a, b)
        comparable_reflection(a) == comparable_reflection(b)
      end

      # Get the parent of the reflection if it has one.
      # In AR4, #parent_reflection returns [name, reflection]
      # In AR5, #parent_reflection returns just a reflection
      def comparable_reflection(reflection)
        [*reflection.parent_reflection].last || reflection
      end
    end
  end
end